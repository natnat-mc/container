import getini, loaddefaults, checkconfig, mountmachine, nspawnargs from require 'containerutil'
import runorerror from require 'exec'
State=require 'State'
Command=require 'Command'

with Command 'boot'
	.args={
		{'name', required: true}
	}
	.desc="Boots a container"
	.help={
		"Starts a container in foreground, without any form of control"
		"The container is started with systemd-nspawn, according to the rules in its config.ini"
		"If you want to be able to detach the container, you probably want `container start` or `container here` instead"
	}
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
			
			-- get env variables for systemd
			env=ini\getlist 'machine', 'env'
			
			-- boot our container
			runorerror "env #{table.concat env, ' '} systemd-nspawn", args
		
		-- release our machine
		State\release 'machine', machine
		
		-- exit
		error err unless ok
		return 0
