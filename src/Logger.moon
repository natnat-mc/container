import ensuredir from require 'exec'
GlobalConfig=require 'GlobalConfig'

class Logger
	@use: (service) =>
		logdir=GlobalConfig\get 'general', 'logdir', '/var/log/container'
		ensuredir logdir
		@file=io.open "#{logdir}/#{service}.log", "a"
	@close: () =>
		@file\close!
		@file=nil
	
	@_log: (level, msg) =>
		@file\write "[", os.date("%Y-%m-%d %H:%M:%S"), "][", level\upper!, "] ", msg, "\n"
		@file\flush!
	
	@log: (msg) => @_log 'log', msg
	@info: (msg) => @_log 'info', msg
	@err: (msg) => @_log 'err', msg
	@warn: (msg) => @_log 'warn', msg
