--====================================================================--
-- dmc-mockserver-simple
--
-- answer an app's requests and downloads with a mock server, as if
-- from https://api.example.com
--====================================================================--

print( "\n\n#########################################################\n\n" )



--====================================================================--
--== Imports


local json = require 'json'
local MockServer = require 'dmc_corona.dmc_mockserver'



--====================================================================--
--== Setup, Constants


local W, H = display.contentWidth, display.contentHeight
local H_CENTER = W*0.5

local API = 'https://api.example.com'

local USERS = {
	['1'] = { id=1, name="Ada" },
	['2'] = { id=2, name="Grace" },
}

local result_txt, avatar
local pending_id -- the request Cancel cancels

display.setDefault( 'background', 0.95, 0.95, 0.95 )



--====================================================================--
--== The Mock Server


local mock = MockServer:new{ delay=800 }

-- GET /users/<id>: a function makes the body
mock:requestRespondWith( 'GET', '^/users/(%d+)$', {
	200, { ['Content-Type']='application/json' },
	function( url, method, params, status, headers )
		local id = url:match( '/users/(%d+)$' )
		local user = USERS[ id ] or {}
		return json.encode( user )
	end
})

-- POST /login: a string is the body
mock:requestRespondWith( 'POST', '^/login$', {
	200, { ['Content-Type']='application/json' }, '{"token":"abc123"}'
})

-- GET /avatar.png: the function writes the file
mock:downloadRespondWith( 'GET', '^/avatar%.png$', {
	200, { ['Content-Type']='image/png' },
	function( url, method, params, filename, base_dir )
		local src = io.open( system.pathForFile( 'data/avatar.png', system.ResourceDirectory ), 'rb' )
		local dst = io.open( system.pathForFile( filename, base_dir ), 'wb' )
		dst:write( src:read( '*a' ) )
		src:close() ; dst:close()
		return true
	end
})

-- only requests to API are mocked; others go to the network
mock:addRequestFilter( function( url ) return url:sub( 1, #API )==API end )



--====================================================================--
--== Support Functions


local function show( text )
	result_txt.text = text
	print( text )
end

local function onRequest( event )
	pending_id = nil
	if event.isError then
		show( "network error" )
	else
		show( "status " .. event.status .. "\n" .. event.response )
	end
end

local function onDownload( event )
	pending_id = nil
	if event.isError or event.status~=200 then
		show( "download: status " .. event.status ) ; return
	end
	show( "downloaded " .. event.response.filename )
	if avatar then avatar:removeSelf() end
	avatar = display.newImage( event.response.filename, event.response.baseDirectory, H_CENTER, H-70 )
end

local function newButton( label, y, onTap )
	local bg = display.newRoundedRect( H_CENTER, y, 240, 36, 6 )
	bg:setFillColor( 0.25, 0.45, 0.8 )
	local txt = display.newText( label, H_CENTER, y, native.systemFont, 16 )
	bg:addEventListener( 'tap', function() onTap() ; return true end )
	return bg, txt
end



--====================================================================--
--== Main


local title = display.newText( "dmc-mockserver", H_CENTER, 30, native.systemFontBold, 20 )
title:setFillColor( 0.2, 0.2, 0.2 )

newButton( "GET /users/2", 80, function()
	show( "requesting /users/2 ..." )
	pending_id = mock.request( API .. '/users/2', 'GET', onRequest )
end)

newButton( "POST /login", 125, function()
	show( "posting /login ..." )
	pending_id = mock.request( API .. '/login', 'POST', onRequest, { body="user=ada" } )
end)

newButton( "GET /missing (404)", 170, function()
	show( "requesting /missing ..." )
	pending_id = mock.request( API .. '/missing', 'GET', onRequest )
end)

newButton( "Download /avatar.png", 215, function()
	show( "downloading /avatar.png ..." )
	pending_id = mock.download( API .. '/avatar.png', 'GET', onDownload, 'avatar.png', system.TemporaryDirectory )
end)

newButton( "Cancel", 260, function()
	if pending_id and mock.cancel( pending_id ) then
		show( "cancelled" )
	else
		show( "nothing to cancel" )
	end
	pending_id = nil
end)

result_txt = display.newText{ text="tap a button", x=H_CENTER, y=330, width=280, font=native.systemFont, fontSize=14, align='center' }
result_txt:setFillColor( 0.1, 0.1, 0.1 )
