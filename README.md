# dmc-mockserver

Mock your server's API in a Solar2D (formerly Corona SDK) app, to build and test it before the server exists, or without a network.

A mock server has the same calls as Solar2D's `network` library. Tell it what to answer for each URL; it calls your listener after a delay, with the event the network would send:

```lua
local MockServer = require 'dmc_corona.dmc_mockserver'

local mock = MockServer:new()
mock:requestRespondWith( 'GET', '^/users/%d+$', { 200, {}, '{"name":"Grace"}' } )

mock.request( 'https://api.example.com/users/2', 'GET', function( event )
	print( event.status, event.response )  -- 200  {"name":"Grace"}
end )
```

## Features

- `request()`, `download()` and `cancel()`, called like `network.request()`, `network.download()` and `network.cancel()`
- Responses by request type, HTTP method and a Lua pattern on the URL's path
- A response body as a string, or from a function of the request; a download's function writes the file
- Listener events shaped like Solar2D's: `status`, `response`, `responseHeaders`, `requestId`, and `event.response.filename` for a download
- A URL with no response gets a 404; a function returning `nil` simulates a network error
- Filters: mock some requests and send the rest to the real network
- Several mock servers in one app, each with its own responses and delay
- MIT licensed

## Quick Start

The following code will get you up and running in about 10 minutes in the Solar2D Simulator on macOS or Windows. It makes an app that asks a mock server for a user, then for a page that doesn't exist.

Prerequisites: the [Solar2D](https://solar2d.com/) Simulator and a copy of this repository (`git clone https://github.com/dmccuskey/dmc-mockserver.git`, or download the ZIP from GitHub).

### 1. Copy the Library into Your Project

Copy these from this repository into the root of your project folder:

```text
dmc_corona_boot.lua     loader for the DMC libraries
dmc_corona.cfg          configuration
dmc_corona/             dmc-mockserver and the libraries it uses
```

**Going further:** keep the libraries in a subfolder, or combine several DMC libraries ([dmc-corona-boot Configuration](https://github.com/dmccuskey/dmc-corona-boot/blob/master/docs/configuration.md)).

### 2. Mock a Request

Create `main.lua` in the project folder:

```lua
local json = require 'json'
local MockServer = require 'dmc_corona.dmc_mockserver'

local USERS = { ['1']="Ada", ['2']="Grace" }

local mock = MockServer:new{ delay=300 }

-- GET /users/<id>: the function makes the body
mock:requestRespondWith( 'GET', '^/users/%d+$', {
	200, { ['Content-Type']='application/json' },
	function( url, method, params, status, headers )
		local id = url:match( '/users/(%d+)$' )
		return json.encode{ id=tonumber( id ), name=USERS[ id ] }
	end
})

local function onResponse( event )
	print( event.url, event.status, event.response )
end

mock.request( 'https://api.example.com/users/2', 'GET', onResponse )
```

Open `main.lua` in the Simulator. After the delay, the console shows (the JSON's key order may differ):

```text
https://api.example.com/users/2	200	{"id":2,"name":"Grace"}
```

### 3. Ask for Something Else

Add this to the end of `main.lua`:

```lua
mock.request( 'https://api.example.com/teams/1', 'GET', onResponse )
```

The Simulator restarts the app when the file is saved. Nothing answers `/teams/1`, so the mock server sends a 404, as a server would, and says so:

```text
https://api.example.com/users/2	200	{"id":2,"name":"Grace"}
MockServer: no response for GET 'https://api.example.com/teams/1', answering 404
https://api.example.com/teams/1	404
```

When the server is ready, call `network.request()` instead: the listener stays the same. One way is to pick the library at the top of your code, `local net = USE_MOCK and mock or network`, then call `net.request()`.

For downloads, a POST and cancelling a request, see the [example](examples/README.md).

To update, copy `dmc_corona_boot.lua` and `dmc_corona/` again from the newer version. Keep your own `dmc_corona.cfg` if you have changed it.

## Reference

`require 'dmc_corona.dmc_mockserver'` returns the `MockServer` class, a [dmc-objects](https://github.com/dmccuskey/dmc-objects) `ObjectBase`. `MockServer.VERSION` is the module's version (`"2.0.0"`).

### `MockServer:new( params )`

| param | default | effect |
|---|---|---|
| `delay` | `500` (`MockServer.REQUEST_DELAY`) | milliseconds before a mocked response; also the `mock.delay` property |
| `debug_on` | the cfg's `DEBUG_ACTIVE` | prints each request: mocked, with its status, or passed on |

`mock:removeSelf()` cancels the requests it hasn't answered.

### `mock:respondWith( req_type, method, url, response )`

Adds a response. `req_type` is `MockServer.REQUEST` (`'request'`) or `MockServer.DOWNLOAD` (`'download'`); `method` is the HTTP method, any case. `url` is a Lua pattern matched against the URL's path (`/users/2` in `https://api.example.com/users/2?x=1`): anchor it with `^` and `$` to match the whole path, and escape `.` and `-` as `%.` and `%-`. The first response added whose pattern matches is used.

`response` is `{ status, headers, body }`:

| | request | download |
|---|---|---|
| `status` | the event's `status`, eg `200` | the same |
| `headers` | the event's `responseHeaders`, a table | the same |
| `body` | a string, the event's `response`; or `function( url, method, params, status, headers )` returning it | `function( url, method, params, filename, baseDirectory, status, headers )`, which writes the file and returns `true` |

A function returning `nil` (a request) or `false` (a download) simulates a network error: the event has `isError = true` and `status = -1`.

`mock:requestRespondWith( method, url, response )` and `mock:downloadRespondWith( method, url, response )` are the same for one type.

### `mock.request( url, method, listener, params )`

Like `network.request()`, with a dot. `method` defaults to `'GET'`. If the request filter says so (see below), the request goes to `network.request()` and its return value is returned. Otherwise the mock server answers after the delay, calling `listener` with an event:

| field | value |
|---|---|
| `name`, `phase` | `'networkRequest'`, `'ended'` |
| `isError` | `false`, or `true` for a simulated network error |
| `status` | the response's status; `404` when no response matches; `-1` for a network error |
| `response` | the body, a string (`''` for a 404) |
| `responseHeaders`, `responseType` | the response's headers, `'text'` |
| `url`, `bytesTransferred` | the URL asked for, the body's length |
| `requestId` | the value `mock.request()` returned |

Returns the request id, for `mock.cancel()`.

### `mock.download( url, method, listener, params, filename, baseDirectory )`

Like `network.download()`, with a dot: `params` and `baseDirectory` are optional, `baseDirectory` defaults to `system.DocumentsDirectory`. A download the filter passes on goes to `network.download()`. The event is the request's, except that `response` is a table, `{ filename=, baseDirectory= }`, and there is no `responseType`. The response function writes the file.

### `mock.cancel( requestId )`

Like `network.cancel()`. A mocked request is never answered; returns `true`, or `false` when it was answered or cancelled already. An id from the real network is passed to `network.cancel()`.

### Filters

`mock:addRequestFilter( func )` and `mock:addDownloadFilter( func )` (or `mock:addFilter( req_type, func )`) set the filter for one type: `func( url, method, params )` returns `true` for a request the mock server answers; the others go to the network. `nil` removes the filter: the mock server answers every request, its default.

```lua
-- mock only our API
mock:addRequestFilter( function( url )
	return url:find( '^https://api%.example%.com/' ) ~= nil
end )
```

## Configuration

The `[DMC_MOCKSERVER]` section of `dmc_corona.cfg` (see [dmc-corona-boot Configuration](https://github.com/dmccuskey/dmc-corona-boot/blob/master/docs/configuration.md) for the file's format):

| key | values | default | effect |
|---|---|---|---|
| `DEBUG_ACTIVE:BOOL` | `true`, `false` | `false` | prints each request; a mock server's `debug_on` param overrides it |

The `dmc_corona.cfg` in this repository has the section with the key commented out.

## Known Issues

- A listener gets only the `ended` phase: no `began` or `progress` events, whatever `params.progress` says.
- The pattern sees only the URL's path, not its host or query; a body function gets the whole URL to look at them.
- A request id from the mock server is a table, not the network's; cancel it with `mock.cancel()`, not `network.cancel()`.
- The 404 message is printed whatever the debug setting.

Fixed issues are listed in the [CHANGELOG](CHANGELOG.md).

## Development

Only `dmc_corona/dmc_mockserver.lua` is written in this repository. The rest of `dmc_corona/` and `dmc_corona_boot.lua` (and their copies in the example) are generated from [dmc-objects](https://github.com/dmccuskey/dmc-objects), [DMC-Lua-Library](https://github.com/dmccuskey/DMC-Lua-Library) and [dmc-corona-boot](https://github.com/dmccuskey/dmc-corona-boot); fix them there, then rebuild. The copies are made by Snakemake from sibling checkouts (`../dmc-objects`, `../DMC-Corona-Library` for the shared rules, and so on). From this repository's root folder:

```sh
snakemake --cores 1 build_all
```

The tests are in `tests/dmc_mockserver_spec.lua` ([lunatest](https://github.com/silentbicycle/lunatest)). Run them with plain Lua 5.1, with stand-ins for `timer` (timers fire when the test says) and `network` (calls are recorded); they need the `dkjson` and `luasocket` rocks:

```sh
tests/run_unit.sh
```

Then check the [example](examples/README.md) in the Solar2D Simulator: tap each button, and Cancel during a request.

## License

dmc-mockserver is released under the [MIT License](LICENSE).
