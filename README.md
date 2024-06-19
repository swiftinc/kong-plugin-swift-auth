[![Test](https://github.com/swiftinc/kong-plugin-swift-auth/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/swiftinc/kong-plugin-swift-auth/actions/workflows/test.yml)
[![Lint](https://github.com/swiftinc/kong-plugin-swift-auth/actions/workflows/lint.yml/badge.svg?branch=main)](https://github.com/swiftinc/kong-plugin-swift-auth/actions/workflows/lint.yml)

# Kong Swift OAuth plugin

This plugin requests a Swift OAuth2 token and adds the retrieved OAuth access token into
the HTTP Authorization header of proxied requests.

## Table of contents
 - [Requirements](#requirements)
 - [Testing](#testing)

## Requirements

Pongo provides a simple way of testing Kong plugins. For a complete walkthrough [check this blogpost on the Kong website](https://konghq.com/blog/custom-lua-plugin-kong-gateway).

Required tools:

* `docker-compose` (and hence `docker`)
* `curl`
* `realpath`, for older MacOS versions you need the [`coreutils`](https://www.gnu.org/software/coreutils/coreutils.html)
  to be installed. This is easiest via the [Homebrew package manager](https://brew.sh/) by doing:
  ```
  brew install coreutils
  ```
* Depending on your environment you should set some [environment variables](#configuration).

## Testing

### Create an app
[Create an application](https://developer.swift.com/myapps) and select the API products you want to use. `Payment Pre-validation API` and `gpi API` API products have to be selected
to run the integrations tests.

### Do a test run

Clone Pongo repository and install Pongo shell script:
```
PATH=$PATH:~/.local/bin
git clone https://github.com/Kong/kong-pongo.git
mkdir -p ~/.local/bin
ln -s $(realpath kong-pongo/pongo.sh) ~/.local/bin/pongo
```

Clone the plugin repository:

```
git clone https://github.com/swiftinc/kong-plugin-swift-auth.git
cd kong-plugin-swift-auth
```
   
Replace the `__CONSUMER_KEY__` and `__CONSUMER_SECRET__` placeholders from the `spec/swift-auth/01-integration_spec.lua` with the values from the application created in the developer portal:

```
-- ############################################
--      REPLACE BEFORE LAUNCHING THE TESTS
-- ############################################

local consumer_key = "__CONSUMER_KEY__"
local consumer_secret = "__CONSUMER_SECRET__"
      
-- ############################################
```

Auto pull and build the test images:

```
pongo run
```

To directly access Kong from the host, `--expose` argument can be used expose the internal ports to the host:

```
pongo run --expose
```

The above command will automatically build the test image and start the test environment. When done, the test environment can be torn down by:

```
pongo down
```