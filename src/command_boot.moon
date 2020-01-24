import getini, loaddefaults, checkconfig, mountmachine, nspawnargs from require 'containerutil'
import runorerror from require 'exec'
State=require 'State'
Command=require 'Command'

with Command 'boot'
	.args={
		{'name', required: true}
	}
	.desc="Boots a container"
	.fn=(name) ->
		ini=getini name, {machine: true}
		
		-- populate default values
		loaddefaults name, ini
		checkconfig name, ini
		
		-- mount the machine
		machine=mountmachine name
		State\use 'machine', machine
		
		ok, err=pcall () ->
			-- get our nspawn arguments
			args=nspawnargs name, ini, machine, '-b'
			
			-- boot our container
			runorerror 'systemd-nspawn', args
		
		-- release our machine
		State\release 'machine', machine
		
		-- exit
		error err unless ok
		return 0