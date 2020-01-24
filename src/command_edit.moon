import getini from require 'containerutil'
import run from require 'exec'
require 'env'
Command=require 'Command'

with Command 'edit'
	.args={
		{'name', required: true}
		{'editor', required: false}
	}
	.desc="Edits a container config file"
	.help={
		"Edits the container `config.ini` in the given editor"
		"If no editor is given, it will try `$EDITOR`, `$VISUAL` and `vi` in that order"
	}
	.fn=(name, editor) ->
		-- make sure the container exists
		getini name
		
		-- find an editor
		editor=os.getenv 'EDITOR' unless editor
		editor=os.getenv 'VISUAL' unless editor
		editor='vi' unless editor
		
		-- edit the file
		run editor, "#{CONTAINER_DIR}/#{name}/config.ini"
		return 0