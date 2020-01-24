import runorerror from require 'exec'
State=require 'State'
Command=require 'Command'

with Command 'stop-all'
	.args={}
	.desc="Stops all running machines"
	.help={
		"Stops all running containers, without waiting for their death"
	}
	.fn= (name) ->
		for machine, pid in pairs State\runningmachines!
			runorerror 'kill', '-9', pid
			io.write "Stopping machine #{machine}\n"
		return 0