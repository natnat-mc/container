import runorerror from require 'exec'
State=require 'State'
Command=require 'Command'

with Command 'stop'
	.args={
		{'name', required: true}
	}
	.desc="Stops a running machine"
	.fn= (name) ->
		pid=State\machinerunning name
		error "Machine #{name} is not running" unless pid
		runorerror 'kill', '-9', pid
		return 0