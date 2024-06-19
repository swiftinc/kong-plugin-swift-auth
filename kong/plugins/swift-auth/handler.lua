local access = require "kong.plugins.swift-auth.access"
local utils = require "kong.plugins.swift-auth.utils"
local kong = kong

local SwiftAuthHandler = {
  VERSION = "1.0.0",
  PRIORITY = 1000,
}

function SwiftAuthHandler:access(conf)
  local credential = kong.client.get_credential()
  if not credential then
    -- don't open sessions for anonymous users
    return kong.response.error(401, "Anonymous access not allowed", nil)
  end
  access.execute(conf)
end

function SwiftAuthHandler:response(conf)
  -- FIXME This doesn’t work for HTTP/2
  if kong.response.get_status() == 401 then
    kong.log.info("Http status code 401 received. Removing the Swift OAuth token from the cache")
    -- Invalidate the token
    local cache_key = utils.cache_key(conf)
    kong.cache:invalidate(cache_key)
  end
end

return SwiftAuthHandler