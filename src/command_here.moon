import startmachine from require 'containerutil'
import runorerror from require 'exec'
State=require 'State'
Command=require 'Command'

with Command 'here'
	.args={
		{'name', required: true}
	}
	.desc="Starts a machine if required, and attaches it"
	.fn= (name) ->
		pid=startmachine name unless State\machinerunning name
		runorerror 'screen', '-r', "container-#{name}"
		return 0