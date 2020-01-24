import getini, loaddefaults, checkconfig from require 'containerutil'
Command=require 'Command'

with Command 'checkcfg'
	.args={
		{'name', required: true}
	}
	.desc="Checks configuration of a container"
	.help={
		"Checks the configuration of a container"
		"If the configuration is valid, dumps the expanded config to stdout"
	}
	.fn=(name) ->
		-- get container ini file
		ini=getini name
		
		-- populate default values
		loaddefaults name, ini
		checkconfig name, ini, 'warning'
		
		-- if we made it this far, the config is valid
		ini\export!
		return 0