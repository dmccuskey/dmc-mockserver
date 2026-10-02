# Changelog

## 2.0.0 (2026-10-01)

The module is ported to the current DMC libraries, and returns the class instead of one mock server: make one with `MockServer:new()`.

### Fixed

- The module loads again. It used the 2014 boot script and dmc-objects API (`dmc_library_boot`, `Objects.inheritsFrom( Objects.CoronaBase )`) and dmc-utils; it now uses `newClass( ObjectBase )`, dmc-corona-boot and lua_utils.
- A download the filter passes on goes to `network.download()`, not `network.request()`.
- A URL with no response no longer crashes the app (an error in the timer when no response was added for its type or method, or the URL had no path): the listener gets a 404, with `isError = false`, as from a server.
- A download's event has `event.response.filename` and `event.response.baseDirectory`, as from `network.download()`, instead of `filename` and `baseDirectory` on the event.
- `download()` takes `params` as optional, as `network.download()` does, and defaults `baseDirectory` to `system.DocumentsDirectory`.
- A simulated network error (a response function returning `nil` or `false`) has `status = -1`, as from the network.
- No more globals (`f`, `_extend`, `dmc_lib_func`).

### Added

- `mock.cancel( requestId )`, like `network.cancel()`; `request()` and `download()` return a request id, also the event's `requestId`. `mock:removeSelf()` cancels what's pending.
- Several mock servers in one app: `MockServer:new( params )`, with `delay` and `debug_on` params, and a `mock.delay` getter.
- A request's response body can be a string instead of a function.
- HTTP methods in any case; `method` defaults to `'GET'`.
- `addFilter( req_type, nil )` removes a filter.
- `DEBUG_ACTIVE` in the cfg's `[DMC_MOCKSERVER]` section: prints each request.
- `MockServer.VERSION`, and the `Documentation:` link in the header.
- Unit tests (stand-in `timer` and `network`), and `tests/run_unit.sh` to run them with plain Lua 5.1.
- A Snakefile, the built `dmc_corona/`, and an example app, `examples/dmc-mockserver-simple`.

### Removed

- The singleton the module returned.
- The unused `base_path` param and the unused `json`, dmc-files and dmc-utils imports.

## 1.0.0 (2015-02-07)

The first version in this repository: requests and downloads, responses by URL pattern, filters. (The 1.1.0 copy in DMC-Corona-Library, from 2014, is an older design.)
