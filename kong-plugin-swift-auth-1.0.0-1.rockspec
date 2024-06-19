local plugin_name = "swift-auth"
local package_name = "kong-plugin-" .. plugin_name
local package_version = "1.0.0"
local rockspec_revision = "1"

local github_account_name = "swiftinc"
local github_repo_name = "kong-plugin-swift-auth"
local git_checkout = package_version == "dev" and "master" or package_version

package = package_name
version = package_version .. "-" .. rockspec_revision
supported_platforms = { "linux", "macosx" }
source = {
  url = "git+https://github.com/"..github_account_name.."/"..github_repo_name..".git",
  branch = git_checkout,
}

description = {
  summary = "Kong is a scalable and customizable API Management Layer built on top of Nginx.",
  homepage = "https://"..github_account_name..".github.io/"..github_repo_name,
  license = "Swift API sample code",
}

dependencies = {
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins."..plugin_name..".utils"] = "kong/plugins/"..plugin_name.."/utils.lua",
    ["kong.plugins."..plugin_name..".handler"] = "kong/plugins/"..plugin_name.."/handler.lua",
    ["kong.plugins."..plugin_name..".schema"] = "kong/plugins/"..plugin_name.."/schema.lua",
    ["kong.plugins."..plugin_name..".access"] = "kong/plugins/"..plugin_name.."/access.lua",
  }
}
