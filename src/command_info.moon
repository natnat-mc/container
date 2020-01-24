import getini from require 'containerutil'
Command=require 'Command'

with Command 'info'
	.args={
		{'name', required: true}
	}
	.desc="Shows container info"
	.help={
		"Displays the content of the container `config.ini` to stdout"
		"Note that it is the parsed content, so order isn't preserved"
	}
	.fn=(name) ->
		-- dump container INI to stdout
		-- I could pretty-print this, but ¯\_(ツ)_/¯
		(getini name)\export!
		return 0