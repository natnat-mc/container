import startmachine from require 'containerutil'
import runorerror from require 'exec'
State=require 'State'
Command=require 'Command'

with Command 'here'
	.args={
		{'name', required: true}
	}
	.desc="Starts a machine if required, and attaches it"
	.help={
		"If a container is running, immediately attaches it to the current terminal"
		"If the container isn't running, starts it beforehand"
		"If you don't want to attach the container, you might want to use `container start` instead"
	}
	.fn= (name) ->
		pid=startmachine name unless State\machinerunning name
		runorerror 'screen', '-r', "container-#{name}"
		return 0