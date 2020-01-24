import confignetwork from require 'containerutil'
Command=require 'Command'

with Command 'network-start'
	.args={
		{'name', required: true}
	}
	.desc="Sets up a network"
	.fn=(name) ->
		confignetwork name
		return 0