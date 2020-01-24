import getini, loaddefaults, checkconfig, mountmachine, nspawnargs from require 'containerutil'
import runorerror from require 'exec'
State=require 'State'
GlobalConfig=require 'GlobalConfig'
Command=require 'Command'

with Command 'run'
	.args={
		{'name', required: true}
		{'cmd', required: true}
		{'args', required: false, multiple: true}
	}
	.desc="Runs a command in a container"
	.fn=(name, cmd, ...) ->
		if GlobalConfig\allowed 'runcommand'
			ini=getini name, {machine: true}
			
			-- populate default values
			loaddefaults name, ini
			checkconfig name, ini
			
			-- mount the machine
			machine=mountmachine name
			State\use 'machine', machine
			
			-- get our nspawn arguments
			args=nspawnargs name, ini, machine, '-a', cmd, ...
			
			-- run our command in our container
			ok, err=pcall () ->
				runorerror 'systemd-nspawn', args
			
			-- release our machine
			State\release 'machine', machine
			
			-- exit
			error err unless ok
			return 0
		else
			io.stderr\write "systemd-nspawn -a is blacklisted\n"
			return 1