Command=require 'Command'

with Command 'help'
	.args={
		{'command', required: false}
	}
	.desc="Displays help for a command"
	.fn= (command) ->
		unless command
			Command\loadcommands!
			commands=[name for name in pairs Command.commands when not name\match '^%-internal%-']
			table.sort commands
			io.write "Available commands: #{table.concat commands, ", "}\n"
			return
		command=Command\get command
		io.write "#{command.desc}\n"
		io.write "#{command\usage!}\n"
		if command.help
			io.write "\n"
			io.write "#{line}\n" for line in *command.help
		else
			io.write "[no help provided]\n"
		return 0