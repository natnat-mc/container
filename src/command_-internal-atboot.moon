import startmachine, confignetwork from require 'containerutil'
GlobalConfig=require 'GlobalConfig'
Logger=require 'Logger'
Command=require 'Command'

with Command '-internal-atboot'
	.args={}
	.desc="Internal command meant to be run at boot"
	.fn= () ->
		Logger\use 'service'
		errcount=0
		Logger\info "Running one-shot container service"
		for machine in *GlobalConfig\getlist 'general', 'autostart'
			Logger\log "Autostarting container #{machine}"
			ok, err=pcall () ->
				startmachine machine
			unless ok
				Logger\err err
				errcount+=1
		for network in *GlobalConfig\getlist 'general', 'networks'
			Logger\log "Running initial config of network #{network}"
			ok, err=pcall () ->
				confignetwork network
			unless ok
				Logger\err err
				errcount+=1
		if errcount==0
			Logger\info "Finished one-shot container service without error"
		else
			Logger\warn "Finished one-shot container service with #{errcount} error(s)"
		Logger\close!
		return 0