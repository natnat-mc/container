import startmachine from require 'containerutil'
Command=require 'Command'

with Command 'start'
	.args={
		{'name', required: true}
	}
	.desc="Starts a machine in dettached mode"
	.fn= (name) ->
		pid=startmachine name
		io.write "Machine started, init PID is #{pid}\n"
		return 0