import startmachine from require 'containerutil'
Command=require 'Command'

with Command 'start'
	.args={
		{'name', required: true}
	}
	.desc="Starts a machine in detached mode"
	.help={
		"This command starts a container in detached mode, that is, without a controlling terminal"
		"The container can then be attached to a terminal using `container attach`"
		"If you want to bind the container to the current terminal, you might want to use `container boot` instead"
		"If you want to start the container and then attach it to the current terminal, you might want to use `container here` instead"
	}
	.fn= (name) ->
		pid=startmachine name
		io.write "Machine started, init PID is #{pid}\n"
		return 0