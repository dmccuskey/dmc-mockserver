--====================================================================--
-- tests/dmc_mockserver_spec.lua
--
-- unit tests for dmc_mockserver, with a stand-in timer and network;
-- timers fire only in fire()
-- run with tests/run_unit.sh
--====================================================================--


module( ..., package.seeall )


--====================================================================--
--== Setup

-- the timer: performWithDelay() queues, fire() runs what's queued

local timers = {}

_G.timer = {
	performWithDelay=function( delay, f )
		local t = { delay=delay, f=f }
		table.insert( timers, t )
		return t
	end,
	cancel=function( t ) t.cancelled = true end,
}

local function fire()
	local list = timers
	timers = {}
	for _, t in ipairs( list ) do
		if not t.cancelled then t.f() end
	end
end

-- the network: records each call

local net_calls

_G.network = {
	request=function( ... ) table.insert( net_calls, { 'request', ... } ) ; return 'net-id' end,
	download=function( ... ) table.insert( net_calls, { 'download', ... } ) ; return 'net-id' end,
	cancel=function( id ) table.insert( net_calls, { 'cancel', id } ) ; return true end,
}

system.DocumentsDirectory = 'Documents'
system.TemporaryDirectory = 'Temporary'

local MockServer = require 'dmc_corona.dmc_mockserver'

local mock, events

local function listener( event ) table.insert( events, event ) end

function setup()
	timers = {}
	net_calls = {}
	events = {}
	mock = MockServer:new()
end


--====================================================================--
--== Tests


function test_module_returns_the_class()
	assert_string( MockServer.VERSION )
	local other = MockServer:new()
	assert_not_equal( mock, other )
	mock:requestRespondWith( 'GET', '^/a$', { 200, nil, 'A' } )
	other.request( 'http://x/a', 'GET', listener )
	fire()
	assert_equal( 404, events[1].status ) -- other has no responses
end

function test_request_with_a_function()
	local got
	mock:requestRespondWith( 'GET', '^/users/%d+$', { 200, { ['X-A']='1' },
		function( url, method, params, status, headers )
			got = { url, method, params, status, headers }
			return '{"id":2}'
		end
	})
	local params = { body='x' }
	local id = mock.request( 'https://api.example.com/users/2?x=1', 'get', listener, params )
	assert_table( id )
	assert_equal( 0, #events ) -- only after the delay
	assert_equal( MockServer.REQUEST_DELAY, timers[1].delay )
	fire()
	local e = events[1]
	assert_equal( 'networkRequest', e.name )
	assert_equal( 'ended', e.phase )
	assert_false( e.isError )
	assert_equal( 200, e.status )
	assert_equal( '{"id":2}', e.response )
	assert_equal( 8, e.bytesTransferred )
	assert_equal( '1', e.responseHeaders['X-A'] )
	assert_equal( id, e.requestId )
	assert_equal( 'GET', got[2] )
	assert_equal( params, got[3] )
	assert_equal( 0, #net_calls )
end

function test_request_with_a_string()
	mock:requestRespondWith( 'POST', '^/login$', { 201, nil, 'ok' } )
	mock.request( 'http://x/login', 'POST', listener )
	fire()
	assert_equal( 201, events[1].status )
	assert_equal( 'ok', events[1].response )
end

function test_first_matching_pattern_wins()
	mock:requestRespondWith( 'GET', '^/a', { 200, nil, 'first' } )
	mock:requestRespondWith( 'GET', '^/a/b', { 200, nil, 'second' } )
	mock.request( 'http://x/a/b', 'GET', listener )
	fire()
	assert_equal( 'first', events[1].response )
end

function test_request_returning_nil_is_a_network_error()
	mock:requestRespondWith( 'GET', '^/a$', { 200, nil, function() return nil end } )
	mock.request( 'http://x/a', 'GET', listener )
	fire()
	assert_true( events[1].isError )
	assert_equal( -1, events[1].status )
end

function test_unmatched_url_is_404_not_an_error()
	mock:requestRespondWith( 'GET', '^/a$', { 200, nil, 'A' } )
	mock.request( 'http://x/b', 'GET', listener )  -- no matching pattern
	mock.request( 'http://x/a', 'PUT', listener )  -- no responses for the method
	mock.download( 'http://x/a', 'GET', listener, 'f' ) -- none for downloads
	mock.request( 'http://x', 'GET', listener )    -- no path
	fire()
	assert_equal( 4, #events )
	for _, e in ipairs( events ) do
		assert_false( e.isError )
		assert_equal( 404, e.status )
	end
end

function test_download_event_has_response_table()
	local got
	mock:downloadRespondWith( 'GET', '^/f%.png$', { 200, nil,
		function( url, method, params, filename, base_dir ) got = { filename, base_dir } ; return true end
	})
	mock.download( 'http://x/f.png', 'GET', listener, { headers={} }, 'f.png', system.TemporaryDirectory )
	fire()
	local e = events[1]
	assert_false( e.isError )
	assert_equal( 200, e.status )
	assert_equal( 'f.png', e.response.filename )
	assert_equal( 'Temporary', e.response.baseDirectory )
	assert_equal( 'f.png', got[1] )
	assert_nil( e.filename )
end

function test_download_without_params_defaults_to_documents()
	mock:downloadRespondWith( 'GET', '^/f$', { 200, nil, function() return true end } )
	mock.download( 'http://x/f', 'GET', listener, 'f.txt' )
	fire()
	assert_equal( 'f.txt', events[1].response.filename )
	assert_equal( 'Documents', events[1].response.baseDirectory )
end

function test_download_failing_is_a_network_error()
	mock:downloadRespondWith( 'GET', '^/f$', { 200, nil, function() return false end } )
	mock.download( 'http://x/f', 'GET', listener, 'f' )
	fire()
	assert_true( events[1].isError )
	assert_equal( -1, events[1].status )
end

function test_filter_passes_request_to_network()
	mock:addRequestFilter( function( url ) return url:find( 'mock' )~=nil end )
	local id = mock.request( 'http://real/a', 'GET', listener, { body='b' } )
	assert_equal( 'net-id', id )
	assert_equal( 'request', net_calls[1][1] )
	assert_equal( 'http://real/a', net_calls[1][2] )
	assert_equal( 0, #timers )
end

function test_filter_passes_download_to_network_download()
	mock:addDownloadFilter( function() return false end )
	mock.download( 'http://real/f', 'GET', listener, 'f.png', system.TemporaryDirectory )
	local c = net_calls[1]
	assert_equal( 'download', c[1] )
	assert_equal( 'http://real/f', c[2] )
	assert_nil( c[5] ) -- params
	assert_equal( 'f.png', c[6] )
	assert_equal( 'Temporary', c[7] )
end

function test_filter_removed_with_nil()
	mock:addRequestFilter( function() return false end )
	mock:addRequestFilter( nil )
	mock.request( 'http://x/a', 'GET', listener )
	assert_equal( 0, #net_calls )
	assert_equal( 1, #timers )
end

function test_cancel_mocked_request()
	mock:requestRespondWith( 'GET', '^/a$', { 200, nil, 'A' } )
	local id = mock.request( 'http://x/a', 'GET', listener )
	assert_true( mock.cancel( id ) )
	fire()
	assert_equal( 0, #events )
	assert_false( mock.cancel( id ) ) -- already cancelled
	assert_equal( 0, #net_calls )
end

function test_cancel_passes_network_id_to_network()
	mock:addRequestFilter( function() return false end )
	local id = mock.request( 'http://real/a', 'GET', listener )
	mock.cancel( id )
	assert_equal( 'cancel', net_calls[2][1] )
	assert_equal( 'net-id', net_calls[2][2] )
end

function test_delay_param_and_property()
	local m = MockServer:new{ delay=50 }
	assert_equal( 50, m.delay )
	m.delay = 0
	m.request( 'http://x/a', 'GET', listener )
	assert_equal( 0, timers[1].delay )
	assert_error( function() m.delay = 'slow' end )
end

function test_removeSelf_cancels_pending()
	mock:requestRespondWith( 'GET', '^/a$', { 200, nil, 'A' } )
	mock.request( 'http://x/a', 'GET', listener )
	mock:removeSelf()
	fire()
	assert_equal( 0, #events )
end

function test_bad_arguments_raise()
	assert_error( function() mock:respondWith( 'upload', 'GET', '/', {} ) end )
	assert_error( function() mock:requestRespondWith( 'GET', nil, {} ) end )
	assert_error( function() mock:requestRespondWith( 'GET', '/', nil ) end )
	assert_error( function() mock:addFilter( 'upload', function() end ) end )
end

function test_no_globals_leaked()
	for _, name in ipairs{ 'f', '_extend', 'dmc_lib_func', 'MockServer' } do
		assert_nil( rawget( _G, name ), name )
	end
end
