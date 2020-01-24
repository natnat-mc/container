import run from require 'exec'
require 'env'
Command=require 'Command'

with Command 'global-edit'
	.args={
		{'editor', required: false}
	}
	.desc="Edits the global config file"
	.fn=(name, editor) ->
		-- find an editor
		editor=os.getenv 'EDITOR' unless editor
		editor=os.getenv 'VISUAL' unless editor
		editor='vi' unless editor
		
		-- edit the file
		run editor, "#{CONTAINER_DIR}/globalconfig.ini"
		return 0