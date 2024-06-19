local _M = {}


local json = require "cjson"
local http = require "resty.http"
local openssl_digest = require "resty.openssl.digest"
local openssl_pkey = require "resty.openssl.pkey"
local openssl_x509 = require "resty.openssl.x509"
local kong_utils = require "kong.tools.utils"
local utils = require "kong.plugins.swift-auth.utils"
local encode_base64 = ngx.encode_base64
local table_concat = table.concat
local kong = kong
local ngx = ngx

local TOKEN_EXPIRES_IN = 1799

local function b64_url_encode(input)
  local result = encode_base64(input)
  result = result:gsub("+", "-"):gsub("/", "_"):gsub("=", "")
  return result
end

local function get_vault_value(value)
  local return_value = value
  if kong.vault.is_reference(value) then
    local value_vault, err = kong.vault.get(value)
    if err then
      return nil, "Failed to get the " .. value .. " from the vault. " ..  err
    end
    return_value = value_vault
  end
  return return_value
end

local function generate_jwt(conf, url)
  local consumer_key, err = get_vault_value(conf.consumer_key)
  if err then
    return nil, err
  end

  -- Load the certificate
  local certificate, err = kong.db.certificates:select({ id = conf.certificate })
  if err then
    return nil, err
  end
  if not certificate then
    return nil, "Certificate with id " .. conf.certificate .. " not found"
  end

  -- Pasrse the certificate to get the subject name
  local x509_cert, err = openssl_x509.new(certificate.cert, "PEM")
  if err then
    return nil, err
  end

  -- Format the certificate subject name
  local x509_cert_subject = x509_cert:get_subject_name():tostring()
  local sub = string.lower(string.gsub(x509_cert_subject, "/", ","))

  -- Remove certificate labels
  local x5c = string.gsub(certificate.cert, "-----BEGIN CERTIFICATE-----[\n\r]", "")
  x5c = string.gsub(x5c, "-----END CERTIFICATE-----[\n\r]", "")
  x5c = string.gsub(x5c, "[\n\r]", "")

  local header = {
    typ = "JWT",
    alg = "RS256",
    x5c = { x5c }
  }

  local current_time = ngx.time()
  local payload = {
    sub = sub,
    jti = string.gsub(kong_utils.uuid(), "-", ""),
    nbf = current_time,
    iat = current_time,
    exp = current_time + 15,
    iss = consumer_key,
    aud = url
  }

  local segments = {
    b64_url_encode(json.encode(header)),
    b64_url_encode(json.encode(payload))
  }

  local signing_input = table_concat(segments, ".")
  local digest = openssl_digest.new("sha256")
  digest:update(signing_input)

  local signature = openssl_pkey.new(certificate.key):sign(digest)
  segments[#segments+1] = b64_url_encode(signature)

  return table_concat(segments, ".")
end

local function request_oauth2_token(conf)
  kong.log.info("Requesting new Swift OAuth2 access token")

  -- Get the consumer key and secret
  local consumer_key, err = get_vault_value(conf.consumer_key)
  if err then
    return nil, err
  end
  local consumer_secret, err = get_vault_value(conf.consumer_secret)
  if err then
    return nil, err
  end

  local service = kong.router.get_service()
  local url = service.host .. "/oauth2/v1/token"

  local jwt, jwt_err = generate_jwt(conf, url)
  if jwt_err then
    return nil, jwt_err
  end

  local httpc = http.new()
  local res, err = httpc:request_uri("https://" .. url, {
    method = "POST",
    headers = {
      ["Content-Type"] = "application/x-www-form-urlencoded",
      ["Authorization"] = "Basic " .. encode_base64(consumer_key .. ":" .. consumer_secret),
    },
    body = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&scope=" .. conf.scopes .. "&assertion=" .. jwt,
    ssl_verify = true,
  })

  if err or res.status ~= 200 then
    return nil, "Failed to retrieve OAuth token. Received status code: " .. res.status
  end

  return json.decode(res.body)
end

function _M.execute(conf)
  local cache_key = utils.cache_key(conf)

  -- Retrieve a new access token
  local token, err = kong.cache:get(cache_key, {
    ttl = TOKEN_EXPIRES_IN - conf.clock_skew,
    neg_ttl = 0
  }, request_oauth2_token, conf)

  -- Error getting a new access token
  if err then
    kong.log.err(err)
    return kong.response.exit(500, { message = "An unexpected error occurred during Swift OAuth token retrieval" })
  end

  -- Add bearer token
  kong.service.request.set_header("Authorization", "Bearer " .. token.access_token)
end

return _M