require 'env'
INI=require 'INI'
import run from require 'exec'
import isdir from require 'posix'

class State
	@load: () =>
		ok=pcall () -> @ini=INI\parse "#{CONTAINER_WORKDIR}/state.ini"
		@ini=INI! unless ok
		@ini\addsection 'lock'
		@ini\addsection 'uses'
		@save! unless ok

	@save: () =>
		pcall () -> @ini\export "#{CONTAINER_WORKDIR}/state.ini"

	@reentrant: 0

	@acquire: () =>
		return if @reentrant!=0
		while true
			a=os.execute "mkdir \"#{CONTAINER_WORKDIR}/state.lock\" >/dev/null 2>&1"
			break if a==true or a==0
			run 'sleep', '1'
		@reentrant+=1
	@discard: () =>
		@reentrant-=1
		run 'rmdir', "#{CONTAINER_WORKDIR}/state.lock" if @reentrant==0

	@hooks: {}

	@unusedfn: (category, name, fn) =>
		@hooks["unused@#{category}:#{name}"]=fn

	@use: (category, name) =>
		@acquire!
		@load!
		key="#{category}:#{name}"
		count=@ini\get 'uses', key, 0
		@ini\set 'uses', key, count+1
		@save!
		@discard!

	@release: (category, name) =>
		@acquire!
		@load!
		key="#{category}:#{name}"
		count=@ini\get 'uses', key
		count-=1
		count=nil if count==0
		@ini\set 'uses', key, count
		@save!
		unless count
			unusedhook=@hooks["unused@#{category}:#{name}"]
			if unusedhook
				ok, err=pcall unusedhook
				io.stderr\write "Error in unused hook for #{category} #{name}: #{err}" unless ok
		@discard!

	@uses: (category, name) =>
		@acquire!
		@load!
		key="#{category}:#{name}"
		@discard!
		return @ini\get 'uses', key, 0

	@ownlocks: {}

	@lock: (category, name) =>
		key="#{category}:#{name}"
		if @ownlocks[key]
			@ownlocks[key]+=1
			return
		@acquire!
		@load!
		if @ini\get 'lock', key, false
			@discard!
			error "Failed to lock #{category} #{name}"
		@ini\set 'lock', key, true
		@ownlocks[key]=1
		@save!
		@discard!

	@unlock: (category, name) =>
		key="#{category}:#{name}"
		@ownlocks[key]-=1
		return unless @ownlocks[key]==0
		error "lock not owned #{category} #{name}" unless @ownlocks[key]
		@acquire!
		@load!
		@ini\set 'lock', key, nil
		@ownlocks[key]=nil
		@save!
		@discard!

	@addrunningmachine: (name, pid) =>
		@acquire!
		@load!
		@ini\set 'runningmachines', name, pid
		@save!
		@discard!

	@runningmachines: () =>
		@acquire!
		@load!
		running={}
		edited=false
		for name, pid in pairs (@ini.sections.runningmachines or {})
			if isdir "/proc/#{pid}"
				running[name]=pid
			else
				@ini\set 'runningmachines', name, nil
				edited=true
		if edited
			@save!
		@discard!
		return running

	@machinerunning: (name) =>
		@acquire!
		@load!
		pid=@ini\get 'runningmachines', name
		unless pid
			@discard!
			return false
		if isdir "/proc/#{pid}"
			@discard!
			return pid
		else
			@ini\set 'runningmachines', name, nil
			@save!
			@discard!
			return false

	@cleanup: () =>
		needscleanup=next @ownlocks
		unless needscleanup
			if @ini
				for use, count in pairs @ini.sections.uses
					needscleanup=true if count==0
		return unless needscleanup
		@acquire!
		@load!
		for lock in pairs @ownlocks
			@ini\set 'lock', lock, nil
		for use, count in pairs @ini.sections.uses
			if count==0
				@ini\set 'uses', use, nil
				category, name=use\match '^(.-):(.+)$'
				unusedhook=@hooks["unused@#{category}:#{name}"]
				if unusedhook
					ok, err=pcall unusedhook
					io.stderr\write "Error in unused hook for #{category} #{name}: #{err}" unless ok
		@save!
		@discard!
