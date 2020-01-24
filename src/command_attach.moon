import runorerror from require 'exec'
State=require 'State'
Command=require 'Command'

with Command 'attach'
	.args={
		{'name', required: true}
	}
	.desc="Attaches a machine which was started in dettached mode"
	.help={
		"Attaches the given container to the current terminal"
		"If the container isn't running, the command fails"
		"If you want to start the container if it isn't running, you might want to use `container here` instead"
	}
	.fn= (name) ->
		error "Machine #{name} is not running" unless State\machinerunning name
		runorerror 'screen', '-r', "container-#{name}"
		return 0