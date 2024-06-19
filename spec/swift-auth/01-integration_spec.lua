local helpers = require "spec.helpers"
local openssl_x509 = require "resty.openssl.x509"
local openssl_bignum = require "resty.openssl.bn"
local openssl_rand = require "resty.openssl.rand"
local openssl_pkey = require "resty.openssl.pkey"
local x509_name = require "resty.openssl.x509.name"

local PLUGIN_NAME = "swift-auth"

local function generate_self_signed()
  local key = openssl_pkey.new { bits = 2048 }
  local crt = openssl_x509.new()
  crt:set_pubkey(key)
  crt:set_version(3)  crt:set_serial_number(openssl_bignum.from_binary(openssl_rand.bytes(16)))
  local now = os.time()
  crt:set_not_before(now)
  crt:set_not_after(now + 86400 * 20 * 365)   -- last for 20 years
  local name = x509_name.new():add("O", "swift"):add("CN", "selfsigned")
  crt:set_subject_name(name)
  crt:set_issuer_name(name)
  crt:sign(key)
  return key:to_PEM("private"), crt:to_PEM()
end

for _, strategy in helpers.all_strategies() do if strategy ~= "cassandra" and strategy ~= "off" then
  describe(PLUGIN_NAME .. ": (access) [#" .. strategy .. "]", function()
    local client

    lazy_setup(function()

      -- ############################################
      --      REPLACE BEFORE LAUNCHING THE TESTS
      -- ############################################

      local consumer_key = "__CONSUMER_KEY__"
      local consumer_secret = "__CONSUMER_SECRET__"
      
      -- ############################################

      assert.not_same(consumer_key, "__CONSUMER_KEY__", "Replace the consumer key before launching the test!!")
      assert.not_same(consumer_secret, "__CONSUMER_SECRET__", "Replace the consumer secret before launching the test!!")

      helpers.setenv("CONSUMER_KEY", consumer_key)
      helpers.setenv("CONSUMER_SECRET", consumer_secret)

      local db = helpers.get_db_utils(strategy, nil, { PLUGIN_NAME }, { "env" })

      -- Generate a self-signed certificate
      local key, crt = generate_self_signed()
      local cert = db.certificates:insert {
        cert = crt,
        key = key,
        tags = { "swift-oauth" },
      }

      -- Create environment variables vault
      db.vaults:insert {
        prefix = "test-vault",
        name = "env"
      }

      -- Insert consumer and credentials
      local consumer = db.consumers:insert {
        username = "bob"
      }

      db.keyauth_credentials:insert {
        key = "secret",
        consumer = { id = consumer.id },
      }

      -- Insert service
      local service = db.services:insert {
        name= "swift-sandbox",
        url = "https://sandbox.swift.com",
      }

      -- Insert routes
      local preval_route = db.routes:insert({
        name = "swift-preval",
        paths = { "/swift-preval" },
        service = service,
        strip_path = false,
      })

      local gpi_route = db.routes:insert({
        name = "swift-gpi",
        paths = { "/swift-apitracker" },
        service = service,
        strip_path = false,
      })

      -- Add plugins
      db.plugins:insert {
        name = PLUGIN_NAME,
        instance_name = "Swift-PreValidation",
        route = { id = preval_route.id },
        config = {
          consumer_key = consumer_key,
          consumer_secret = consumer_secret,
          scopes = "swift.preval!p",
          certificate = cert.id
        },
      }

      db.plugins:insert {
        name = PLUGIN_NAME,
        instance_name = "Swift-GPI",
        route = { id = gpi_route.id },
        config = {
          consumer_key = "{vault://test-vault/consumer-key}",
          consumer_secret = "{vault://test-vault/consumer-secret}",
          scopes = "swift.apitracker",
          certificate = cert.id
        },
      }

      db.plugins:insert {
        name     = "key-auth",
        service = { id = service.id }
      }

      -- Start kong
      assert(helpers.start_kong({
        database = strategy,
        nginx_conf = "spec/fixtures/custom_nginx.template",
        plugins = "bundled," .. PLUGIN_NAME,
        -- Write & load declarative config, only if 'strategy=off'
        declarative_config = strategy == "off" and helpers.make_yaml_file() or nil,
        vaults = "env"
      }))
    end)

    lazy_teardown(function()
      helpers.stop_kong(nil, true)
    end)

    before_each(function()
      client = helpers.proxy_client()
    end)

    after_each(function()
      if client then client:close() end
    end)

    describe("request", function()
      it("Swift Pre-val request", function()
        local res = client:post("/swift-preval-pilot/v2/accounts/verification", {
          body = {
            ["correlation_identifier"] = "112211221122",
            ["context"] = "BENR",
            ["uetr"] = "97ed4827-7b6f-4491-a06f-b548d5a7512d",
            ["creditor_account"] = "7892368367",
            ["creditor_name"] = "DEF Electronics",
            ["creditor_agent"] = {
              ["bicfi"] = "AAAAUS2L"
            },
            ["creditor_agent_branch_identification"] = "NY8877888"
          },
          headers = {
            ["Content-Type"] = "application/json",
            ["x-bic"] = "cclabebb",
            ["apiKey"] = "secret"
          }
        })
        assert.response(res).has.status(200)
      end)

      it("Swift gpi request", function()
        local res = client:get("/swift-apitracker/v5/payments/97ed4827-7b6f-4491-a06f-b548d5a7512d/transactions", {
          headers = {
            ["Content-Type"] = "application/json",
            ["apiKey"] = "secret"
          }
        })
        assert.response(res).has.status(200)
      end)
    end)
  end)
end end