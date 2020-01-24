import startmachine, confignetwork, hasnetwork, networkstate from require 'containerutil'
GlobalConfig=require 'GlobalConfig'
Logger=require 'Logger'
State=require 'State'
Command=require 'Command'

with Command '-internal-cronjob'
	.args={}
	.desc="Internal command meant to be run in a cron job"
	.fn= () ->
		Logger\use 'cronjob'
		errcount=0
		actioncount=0
		for machine in *GlobalConfig\getlist 'general', 'autorestart'
			ok, err=pcall () ->
				unless State\machinerunning machine
					actioncount+=1
					Logger\log "Restarting machine #{machine}"
					startmachine machine
			unless ok
				Logerr\err err
				errcount+=1
		for network in *GlobalConfig\getlist 'general', 'networks'
			ok, err=pcall () ->
				iface=GlobalConfig\get "network \"#{network}\"", 'interface'
				if (hasnetwork iface) and 'down'==networkstate iface
					actioncount+=1
					Logger\log "Running config of network #{network}"
					confignetwork network
			unless ok
				Logger\err err
				errcount+=1
		if actioncount!=0
			Logger\info "Finished container cron job: done #{actioncount} actions"
		if errcount!=0
			Logger\warn "Encountered #{errcount} errors"
		Logger\close!
		return 0