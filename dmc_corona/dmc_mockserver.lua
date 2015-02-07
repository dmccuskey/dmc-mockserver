--====================================================================--
-- dmc_mockserver.lua
--
--
-- by David McCuskey
-- Documentation:
--====================================================================--

--[[

Copyright (C) 2013-2014 David McCuskey. All Rights Reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in the
Software without restriction, including without limitation the rights to use, copy,
modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so, subject to the
following conditions:

The above copyright notice and this permission notice shall be included in all copies
or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

--]]


-- Semantic Versioning Specification: http://semver.org/

local VERSION = "1.0.0"




--====================================================================--
-- DMC Library Support Methods
--====================================================================--

local Utils = {}

function Utils.extend( fromTable, toTable )

	function _extend( fT, tT )

		for k,v in pairs( fT ) do

			if type( fT[ k ] ) == "table" and
				type( tT[ k ] ) == "table" then

				tT[ k ] = _extend( fT[ k ], tT[ k ] )

			elseif type( fT[ k ] ) == "table" then
				tT[ k ] = _extend( fT[ k ], {} )

			else
				tT[ k ] = v
			end
		end

		return tT
	end

	return _extend( fromTable, toTable )
end



--====================================================================--
-- DMC Library Config
--====================================================================--

local dmc_lib_data, dmc_lib_info, dmc_lib_location

-- boot dmc_library with boot script or
-- setup basic defaults if it doesn't exist
--
if false == pcall( function() require( "dmc_library_boot" ) end ) then
	_G.__dmc_library = {
		dmc_library={
			location = ''
		},
		func = {
			find=function( name )
				local loc = ''
				if dmc_lib_data[name] and dmc_lib_data[name].location then
					loc = dmc_lib_data[name].location
				else
					loc = dmc_lib_info.location
				end
				if loc ~= '' and string.sub( loc, -1 ) ~= '.' then
					loc = loc .. '.'
				end
				return loc .. name
			end
		}
	}
end

dmc_lib_data = _G.__dmc_library
dmc_lib_func = dmc_lib_data.func
dmc_lib_info = dmc_lib_data.dmc_library
dmc_lib_location = dmc_lib_info.location




--====================================================================--
-- DMC Library : DMC Mock Server
--====================================================================--




--====================================================================--
-- DMC Mock Server Config
--====================================================================--

dmc_lib_data.dmc_mockserver = dmc_lib_data.dmc_mockserver or {}

local DMC_MOCKSERVER_DEFAULTS = {
	-- none
}

local dmc_utils_data = Utils.extend( dmc_lib_data.dmc_mockserver, DMC_MOCKSERVER_DEFAULTS )




--====================================================================--
-- Imports
--====================================================================--

local json = require( "json" )
local urllib = require( 'socket.url' )

local Objects = require( dmc_lib_func.find('dmc_objects') )
local Utils = require( dmc_lib_func.find('dmc_utils') )
local Files = require( dmc_lib_func.find('dmc_files') )



--====================================================================--
-- Setup, Constants
--====================================================================--

-- setup some aliases to make code cleaner
local inheritsFrom = Objects.inheritsFrom
local CoronaBase = Objects.CoronaBase


local MockSingleton = nil


--====================================================================--
-- Mock Server Class
--====================================================================--

local MockServer = inheritsFrom( CoronaBase )
MockServer.NAME = "DMC Library Mock Server"


--== Class Constants

MockServer.REQUEST_DELAY = 500 -- milliseconds

MockServer.DOWNLOAD = 'download'
MockServer.REQUEST = 'request'



--====================================================================--
--== Start: Setup DMC Objects


function MockServer:_init( params )
	-- print( "MockServer:_init" )
	self:superCall( "_init", params )
	--==--

	params = params or {}

	--== Create Properties ==--

	self._base_path = params.base_path

	self._network = _G.network
	self._filter = nil -- table of filter functions
	self._actions = nil -- table of possible responses

	self._request_delay = params.delay or self.REQUEST_DELAY

	--== Display Groups ==--

	--== Object References ==--

end



-- _initComplete()
--
function MockServer:_initComplete()
	-- print( "MockServer:_initComplete" )
	self:superCall( "_initComplete" )
	--==--

	self._actions = {}
	self._filter = {}

	-- setup network.* API on object
	-- required so we act like object, not module
	self.request = self:createCallback( self._request )
	self.download = self:createCallback( self._download )

	-- base setup, we accept anything
	self:addFilter( function( url, method ) return true end )

end

function MockServer:_undoInitComplete()
	--==--
	self:superCall( "_undoInitComplete" )
end


--== END: Setup DMC Objects
--====================================================================--



--====================================================================--
--== Class API Methods


function MockServer.__setters:delay( value )
	-- print( "MockServer.__setters:delay ", value )
	self._request_delay = value
end



--[[


{
	download={
		'POST'={
			{
				url='',
				action={}
			}
		}
	}

}

--]]

function MockServer:respondWith( req_type, method, url, response )
	-- print( "MockServer:respondWith", req_type, method, url, response )

	local resp_hash = self._actions
	local resp_list, item

	-- check for request type, eg 'download'
	if not resp_hash[ req_type ] then resp_hash[ req_type ] = {} end
	resp_hash = resp_hash[ req_type ]

	-- check for http method, eg 'POST'
	if not resp_hash[ method ] then resp_hash[ method ] = {} end
	resp_list = resp_hash[ method ]

	item = {
		url=url,
		action=response
	}
	table.insert( resp_list, item )

end


-- convenience function
--
function MockServer:requestRespondWith( method, url, response )
	-- print( "MockServer:requestRespondWith", method, url, response  )
	self:respondWith( self.REQUEST, method, url, response )
end
-- convenience function
--
function MockServer:downloadRespondWith( method, url, response )
	-- print( "MockServer:downloadRespondWith", method, url, response  )
	self:respondWith( self.DOWNLOAD, method, url, response )
end


-- convenience function
--
function MockServer:addFilter( req_type, req_filter )
	-- print( "MockServer:addFilter", req_type, req_filter  )
	self._filter[ req_type ] = req_filter
end


-- convenience function
--
function MockServer:addRequestFilter( req_filter )
	-- print( "MockServer:addRequestFilter", req_filter  )
	self:addFilter( self.REQUEST, req_filter )
end
-- convenience function
--
function MockServer:addDownloadFilter( req_filter )
	-- print( "MockServer:addDownloadFilter", req_filter  )
	self:addFilter( self.DOWNLOAD, req_filter )
end





--====================================================================--
--== Corona API Response Methods



function MockServer:_request( url, method, callback, params )
	-- print( "MockServer:_request", url, method, callback, params )

	if not self:_mockHandlesRequestResponse( url, method, params ) then
		return network.request( url, method, callback, params )

	else
		f = function()
			return self:_doRequestResponse( url, method, callback, params )
		end
		timer.performWithDelay( self._request_delay, f )

	end

end

function MockServer:_download( url, method, callback, params, filename, base_dir )
	-- print( "MockServer:_download", url, method, callback, params, filename, base_dir )

	if not self:_mockHandlesDownloadResponse( url, method, params ) then
		return network.request( url, method, callback, params, filename, base_dir )

	else
		f = function()
			return self:_doDownloadResponse( url, method, callback, params, filename, base_dir )
		end
		timer.performWithDelay( self._request_delay, f )

	end

end



--====================================================================--
--== Private Methods



-- _mockHandlesRequest()
-- test if we are to handle or pass on request
--
function MockServer:_mockHandlesResponse( req_type, url, method, params )
	-- print( "MockServer:_mockHandlesResponse", req_type, url, method, params  )

	local filter = self._filter[ req_type ]

	if not filter then
		return true
	else
		return filter( url, method, params )
	end
end

function MockServer:_mockHandlesRequestResponse( url, method, params )
	-- print( "MockServer:_mockHandlesRequestResponse", url, method, params  )
	return self:_mockHandlesResponse( self.REQUEST, url, method, params )
end
function MockServer:_mockHandlesDownloadResponse( url, method, params )
	-- print( "MockServer:_mockHandlesDownloadResponse", url, method, params  )
	return self:_mockHandlesResponse( self.DOWNLOAD, url, method, params )
end




function MockServer:_findAction( req_type, url, method )
	-- print( "MockServer:_findAction", req_type, url, method  )

	local url_parts = urllib.parse( url )

	local resp_hash, resp_list
	local action, response

	if not url or not url_parts then return response end


	resp_hash = self._actions[ req_type ]
	if not resp_hash then error( "there are no responses for "..tostring(req_type), 2 ) end
	resp_list = resp_hash[ method ]
	if not resp_list then error( "there are no items for "..tostring(method), 2 ) end

	-- Utils.print( url_parts )

	for i,v in ipairs( resp_list ) do
		local reg_exp = v.url
		local action = v.action

		-- print( "COMPARE: ", reg_exp, url_parts.path )
		if string.match( url_parts.path, reg_exp ) then
			-- print( "FOUDN ACTION!!!!" )
			response = action
			break
		end

	end

	return response
end

function MockServer:_findRequestAction( url, method )
	return self:_findAction( self.REQUEST, url, method )
end
function MockServer:_findDownloadAction( url, method )
	return self:_findAction( self.DOWNLOAD, url, method )
end




function MockServer:_doRequestResponse( url, method, callback, params )
	-- print( "MockServer:_doRequestResponse", url, method, callback, params )

	local action, data, event

	--== Create HTTP response with Corona Event

	event = {
		isError=false,

		name='networkRequest',
		phase='ended',

		responseType='text',

		responseHeaders=nil,
		url=url,
		bytesTransferred=0,

		status=nil, -- 200, etc
		response=data, -- json encoded data

		requestId='??',
	}

	--== Check our setup


	action = self:_findRequestAction( url, method )

	if not action then
		event.isError = true
		event.status = 500
		print( "Mock Server: couldn't find action for '"..tostring( url ).."'", 2 )

	else

		local resp_status, resp_headers, resp_func = unpack( action )
		-- print( resp_status, resp_headers, resp_func  )

		data = resp_func( url, method, params, resp_status, resp_headers )

		event.status = resp_status
		event.responseHeaders = resp_headers

		--== Create HTTP response with Corona Event

		if not data then
			event.isError = true
			event.bytesTransferred=0
			event.response=nil

		else
			event.isError = false
			event.bytesTransferred=#data
			event.response=data

		end
	end

	if callback then callback( event ) end

end




function MockServer:_doDownloadResponse( url, method, callback, params, filename, base_dir )
	-- print( "MockServer:_doDownloadResponse", url, method, callback, params, filename, base_dir )

	local action, success, event

	--== Create HTTP response with Corona Event

	event = {
		name='networkRequest',
		phase='ended',

		isError=nil,
		status=nil, -- 200, etc

		filename=filename,
		baseDirectory=base_dir,
	}

	--== Check our setup

	action = self:_findDownloadAction( url, method )

	if not action then
		event.isError = true
		event.status = 500
		print( "Mock Server: couldn't find action for '"..tostring( url ).."'", 2 )

	else

		local resp_status, resp_headers, resp_func = unpack( action )
		-- print( resp_status, resp_headers, resp_func  )

		success = resp_func( url, method, params, filename, base_dir, resp_status, resp_headers )

		event.status = resp_status

		if not success then
			event.isError = true
		else
			event.isError = false
		end

	end


	if callback then callback( event ) end

end




--====================================================================--
-- Create Mock Server Singleton
--====================================================================--


MockSingleton = MockServer:new()


return MockSingleton
