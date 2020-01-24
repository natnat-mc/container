#!/usr/bin/env moon

files=[file for file in (io.popen 'ls -1 src')\lines!]
commandfiles=[file for file in *files when file\match 'command_[^%.]+%.moon']
commands=[file\match 'command_([^%.]+)%.moon' for file in *commandfiles]
table.sort commands

io.output arg[1]
io.write 'return {'
for command in *commands
	io.write '"'
	io.write command
	io.write '",'
io.write '}'