State=require 'State'
Command=require 'Command'

with Command 'status'
	.args={
		{'name', required: false}
	}
	.desc="Shows the status of a machine, or lists all the running machines"
	.fn= (name) ->
		if name
			if State\machinerunning name
				io.write "Machine #{name} is running with pid #{State\machinerunning name}\n"
				return 0
			else
				io.write "Machine #{name} is not running\n"
				return 1
		else
			machines=State\runningmachines!
			unless next machines
				io.write "No machine running\n"
				return 1
			longestname=0
			names=[name for name in pairs machines]
			table.sort names
			for name in *names
				longestname=#name if #name>longestname
			for name in *names
				pid=machines[name]
				io.write name
				io.write string.rep ' ', longestname-#name+1
				io.write pid
				io.write '\n'
			return 0