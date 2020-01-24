INI=require 'INI'
import getsystemdversion from require 'exec'
require 'env'

class GlobalConfig
	local ini
	ok, err=pcall () ->
		ini=INI\parse "#{CONTAINER_DIR}/globalconfig.ini"
	unless ok
		io.stderr\write "Can't load gobal config: #{err}\n"
		io.stderr\write "Creating default global config\n"
		ini=INI!
		
		io.stderr\write "Attempting to detect unusable functionality\n"
		ini\addsection 'blacklist'
		systemdversion=getsystemdversion!
		blacklist= (name, ver) ->
			ini\set 'blacklist', name, true if systemdversion<ver
		blacklist '--console', 242
		blacklist '--hostname', 239
		blacklist '--timezone', 239
		blacklist '--resolv-conf', 239
		blacklist 'internalbind', 233
		blacklist '--network-zone', 230
		blacklist 'runcommand', 229
		blacklist '--network-veth-extra', 228
		blacklist '--network-macvlan', 211
		
		ok, err=pcall () ->
			ini\export "#{CONTAINER_DIR}/globalconfig.ini"
		unless ok
			io.stderr\write "Unable to save global config: #{err}\n"
	
	@ifallow: (condition, fn) =>
		fn! unless ini\get 'blacklist', condition
	@allowed: (condition) =>
		not ini\get 'blacklist', condition
	
	@get: (k, v, def) => ini\get k, v, def
	@getlist: (k, v) => ini\getlist k, v
	@getorerror: (k, v) => ini\getorerror k, v
