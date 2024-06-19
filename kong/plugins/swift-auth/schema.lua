local typedefs = require "kong.db.schema.typedefs"
local kong = kong

local function validate_certificate(certificate_id)
  for certificate, err in kong.db.certificates:each(1000) do
    if err then
      return false, "Error when iterating over certificates"
    end
    if certificate_id == certificate.id then
      return true
    end
  end
  return false, "Certificate with id '" .. certificate_id .. "' does not exist"
end

local schema = {
  name = "swift-auth",
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    {
      config = {
        type = "record",
        fields = {
          { consumer_key = { type = "string", required = true, description = "Consumer key" } },
          { consumer_secret = { type = "string", required = true, encrypted = true, description = "Consumer secret" } },
          { scopes = { type = "string", required = true, description = "Name of the service, role and qualifiers, ie 'swift.apitracker/FullViewer' or multiple values 'swift.preval swift.apitracker/Update'" }, },
          { certificate = typedefs.uuid { required = true, description = "The id (a UUID) of the certificate", custom_validator = validate_certificate } },
          { clock_skew = { type = "number", default = 10, between = { 0, 60 }, description = "Clock skew in seconds" }, },
        },
      },
    },
  },
}

return schema
