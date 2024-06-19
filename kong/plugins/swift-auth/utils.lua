local _M = {}

local sha256_hex = require("kong.tools.sha256").sha256_hex
local kong = kong

function _M.cache_key(conf)
  local hash, err = sha256_hex(string.format("%s:%s:%s:%s",
    string.lower(conf.consumer_key),
    string.lower(conf.consumer_secret),
    string.lower(conf.scopes),
    string.lower(conf.certificate)))
  if err then
    kong.log.err(err)
    return kong.response.exit(500, { message = "An unexpected error occurred during Swift OAuth token retrieval" })
  end
  return "swiftauth_tokens:" .. hash
end

return _M
