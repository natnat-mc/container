import runorerror from require 'exec'
State=require 'State'
Command=require 'Command'

with Command 'attach'
	.args={
		{'name', required: true}
	}
	.desc="Attaches a machine which was started in dettached mode"
	.fn= (name) ->
		error "Machine #{name} is not running" unless State\machinerunning name
		runorerror 'screen', '-r', "container-#{name}"
		return 0