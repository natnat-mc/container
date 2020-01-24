import getini from require 'containerutil'
Command=require 'Command'

with Command 'info'
	.args={
		{'name', required: true}
	}
	.desc="Shows container info"
	.fn=(name) ->
		-- dump container INI to stdout
		-- I could pretty-print this, but ¯\_(ツ)_/¯
		(getini name)\export!
		return 0