class Command
	@commands: {}
	
	@get: (name) =>
		return @commands[name] if @commands[name]
		ok, err=pcall require, "command_#{name}"
		unless ok
			error "No such command #{name}"
		return @commands[name]
	
	@loadcommands: () =>
		for command in *require 'command-list'
			require "command_#{command}"
	
	new: (@name) =>
		@args={}
		@@commands[@name]=@
	
	usage: () =>
		fmtarg=(arg) ->
			if arg.required
				return "<#{arg[1]}>"
			else
				if arg.multiple
					return "[#{arg[1]}...]"
				else
					return "[#{arg[1]}]"
		"Usage: #{arg[0]} #{@name} #{table.concat [fmtarg arg for arg in *@args], " "}"