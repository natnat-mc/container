import getallini from require 'containerutil'
Command=require 'Command'

with Command 'list'
	.args={}
	.desc="Lists all containers"
	.fn=() ->
		-- list containers
		containers=getallini!
		unless next containers
			io.write "No containers found\n"
			return
		
		-- pretty-print result
		longestname=0
		names=[name for name in pairs containers]
		table.sort names
		for name in *names
			longestname=#name if #name>longestname
		for name in *names
			ini=containers[name]
			io.write name
			io.write string.rep ' ', (longestname-#name+1)
			if ini\hassection 'layer'
				io.write "[layer] "
			else
				io.write "		"
			if ini\hassection 'machine'
				io.write "[machine]"
			io.write "\n"
		return 0