#!/usr/bin/env moon

VERBOSE=(os.getenv 'VERBOSE') or false
CONTAINER_DIR=(os.getenv 'CONTAINER_DIR') or '/srv/containers'
CONTAINER_WORKDIR=(os.getenv 'CONTAINER_WORKDIR') or '/tmp/containerwork'

escape= (str) ->
	'\"'..(tostring str)\gsub('\\', '\\\\')\gsub('\'', '\\\'')\gsub('\"', '\\\"')..'\"'

run= (prog, ...) ->
	return run prog, (table.unpack or unpack) ... if 'table'==type ((select 1, ...) or nil)
	cmd="#{prog} #{table.concat [escape select i, ... for i=1, select '#', ...], ' '}"
	print cmd if VERBOSE
	a, b, c=os.execute cmd
	return a, c if 'boolean'==type a
	return a==0, a
runorerror= (prog, ...) ->
	error "failed to run #{prog}" unless run prog, ...

try= (options) ->
	import times, delay, fn from options
	for i=1, times
		ok, val=pcall fn
		return val if ok
		run 'sleep', delay if i!=tries

popen= (prog, ...) ->
	return popen prog, (table.unpack or unpack) ... if 'table'==type ((select 1, ...) or nil)
	cmd="#{prog} #{table.concat [escape select i, ... for i=1, select '#', ...], ' '}"
	print cmd if VERBOSE
	io.popen cmd

pread= (prog, ...) ->
	fd=popen prog, ...
	tab=[line for line in fd\lines!]
	fd\close!
	return tab

preadl= (prog, ...) ->
	fd=popen prog, ...
	line=fd\read '*l'
	fd\close!
	return line

exists= (file) -> run '[', '-e', file, ']'
isfile= (file) -> run '[', '-f', file, ']'
isdir= (file) -> run '[', '-d', file, ']'

ls= (dir) ->
	fd=popen 'ls', '-1', dir
	files=[line for line in fd\lines!]
	fd\close!
	files

mkdir= (dir, parents=false) ->
	args={dir}
	table.insert args, '-p' if parents
	run 'mkdir', args

ensuredir= (dir) ->
	return mkdir dir, true unless isdir dir
	return true

mounted= (dir) ->
	run 'mountpoint', '-q', dir
umount= (dir) ->
	run 'umount', dir
	run 'rmdir', '--ignore-fail-on-non-empty', dir

getsystemdversion= () ->
	fd=popen 'systemd-nspawn', '--version'
	version=tonumber (fd\read '*l')\match 'systemd%s([0-9]+)'
	fd\close!
	return version or error "Unable to determine systemd version"

isin= (arr, e) ->
	for v in *arr
		return true if e==v
	return false

class INI
	new: () =>
		@sections={}
	
	addsection: (name) =>
		@sections[name]={} unless @sections[name]
	
	get: (section, key, default=nil) =>
		section=@sections[section]
		return default unless section
		val=section[key]
		return default if val==nil
		return val
	getlist: (section, key) =>
		[item for item in (@get section, key, '')\gmatch '%S+']
	getorerror: (section, key) =>
		error "no such section #{section}" unless @sections[section]
		error "no suck key #{key} in section #{section}" unless nil!=@sections[section][key]
		return @sections[section][key]
	
	has: (section, key) =>
		@sections[section] and @sections[section][key]!=nil
	hassection: (section) =>
		@sections[section]!=nil
	
	set: (section, key, val) =>
		@addsection section
		@sections[section][key]=val
	setlist: (section, key, list) =>
		@set section, key, table.concat list, ' '
	append: (section, key, ...) =>
		list=@getlist section, key
		table.insert list, select i, ... for i=1, select '#', ...
		@set section, key, table.concat list, ' '
	
	export: (filename) =>
		fd=io.stdout
		fd, err=io.open filename, 'w' if filename
		error err unless fd
		for section, data in pairs @sections
			ok, err=fd\write "[#{section}]\n"
			error err unless ok
			for key, value in pairs data
				ok, err=fd\write "#{key} = #{value}\n"
				error err unless ok
		ok, err=fd\close! if filename
		error err unless ok
	
	@parse: (filename, defaultsection='general') =>
		ini=@!
		currentsection=defaultsection
		lineno=0
		parseval= (val) ->
			return true if val=='true'
			return false if val=='false'
			return nil if val=='nil'
			return tonumber val if tonumber val
			val
		for line in io.lines filename
			line=line\match '^%s*(.*)%s*$'
			lineno+=1
			if section=line\match '^%[([^%]]+)%]$'
				currentsection=section
			elseif line\match '^[^=]+=%s*.+$'
				key, val=line\match '^([^=]-)%s*=%s*(.+)$'
				ini\set currentsection, key, parseval val
			elseif (line\match '^#') or line==''
				nil -- comment
			else
				error "line #{lineno}: '#{line}' not understood"
		return ini

class GlobalConfig
	local ini
	ok, err=pcall () ->
		ini=INI\parse "#{CONTAINER_DIR}/globalconfig.ini"
	unless ok
		io.stderr\write "Can't load gobal config: #{err}\n"
		io.stderr\write "Creating default global config\n"
		ini=INI!
		
		io.stderr\write "Attempting to detect unusable functionality\n"
		ini\addsection 'blacklist'
		systemdversion=getsystemdversion!
		blacklist= (name, ver) ->
			ini\set 'blacklist', name, true if systemdversion<ver
		blacklist '--console', 242
		blacklist '--hostname', 239
		blacklist '--timezone', 239
		blacklist '--resolv-conf', 239
		blacklist 'internalbind', 233
		blacklist '--network-zone', 230
		blacklist 'runcommand', 229
		blacklist '--network-veth-extra', 228
		blacklist '--network-macvlan', 211
		
		ok, err=pcall () ->
			ini\export "#{CONTAINER_DIR}/globalconfig.ini"
		unless ok
			io.stderr\write "Unable to save global config: #{err}\n"
	
	@ifallow: (condition, fn) =>
		fn! unless ini\get 'blacklist', condition
	@allowed: (condition) =>
		not ini\get 'blacklist', condition
	
	@get: (k, v, def) => ini\get k, v, def
	@getlist: (k, v) => ini\getlist k, v
	@getorerror: (k, v) => ini\getorerror k, v

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

class Command
	@commands: {}
	
	@get: (name) => @commands[name] or error "No such command #{name}"
	
	new: (@name) =>
		@args={}
		@@commands[@name]=@
	
	usage: () =>
		fmtarg=(arg) ->
			if arg.required
				return "<#{arg[1]}>"
			else
				if arg.multiple
					return "[#{arg[1]}...]"
				else
					return "[#{arg[1]}]"
		"Usage: #{arg[0]} #{@name} #{table.concat [fmtarg arg for arg in *@args], " "}"

-- get a container INI by name
getini= (name, options={}) ->
	error "no name given" unless name
	ok, ini=pcall INI\parse, "#{CONTAINER_DIR}/#{name}/config.ini"
	error "container #{name} not found" unless ok
	error "container #{name} doesn't have a machine" if options.machine and not ini\hassection 'machine'
	error "container #{name} doesn't have a layer" if options.layer and not ini\hassection 'layer'
	return ini

-- get all containers
getallini= (matching={}) ->
	containers={}
	for name in *ls CONTAINER_DIR
		pcall () ->
			containers[name]=getini name, matching
	return containers

-- mount a layer
-- adds one use to the container
mountlayer= (name) ->
	State\lock 'container', name
	
	-- get layer information
	ini=getini name, layer: true
	root="#{CONTAINER_WORKDIR}/layers/#{name}"
	writable=ini\get 'layer', 'writable'
	workdir=if writable then "#{root}/workdir" else nil
	rootfs=if writable then "#{root}/rootfs" else root
	
	unless mounted root -- mount it if it isn't already
		ensuredir root
		t, f=(ini\get 'layer', 'type'), "#{CONTAINER_DIR}/#{name}/#{ini\get 'layer', 'filename'}"
		switch t
			when 'ext4'
				runorerror 'mount', f, root, '-o', "#{writable and 'rw' or 'ro'}"
			when 'squashfs'
				runorerror 'mount', f, root
			when 'directory'
				runorerror 'mount', f, root, '-o', "bind,#{writable and 'rw' or 'ro'}"
			else
				error "unknown fs type #{t}"
		
		if writable -- if the layer is writable, we need a workdir and rootfs
			ensuredir workdir if workdir
			ensuredir rootfs
		
		State\use 'container', name
	
	-- manage layer usage
	State\unusedfn 'layer', root, () ->
		umount root
		State\release 'container', name
	
	-- return our layer
	State\unlock 'container', name
	return {:root, :workdir, :rootfs, :writable}

-- mount a tmpfs
mounttmpfs= (name) ->
	-- find an unused spot
	tmpfsdir="#{CONTAINER_WORKDIR}/tmpfs"
	i=0
	while isdir "#{tmpfsdir}/#{name}-#{i}"
		i+=1
	root="#{tmpfsdir}/#{name}-#{i}"
	
	-- create tmpfs
	writable=true
	workdir="#{root}/workdir"
	rootfs="#{root}/rootfs"
	ensuredir root
	runorerror 'mount', '-t', 'tmpfs', "tmpfs-#{name}", root
	ensuredir workdir
	ensuredir rootfs
	
	-- manage layer usage
	State\unusedfn 'layer', root, () ->
		umount root
	
	-- return our tmpfs layer
	return {:root, :workdir, :rootfs, :writable}

-- merge layer into a merge point
-- adds one use to all the layers
mergelayers= (list, name) ->
	-- find an unused spot
	mergedir="#{CONTAINER_WORKDIR}/merge"
	i=0
	while isdir "#{mergedir}/#{name}-#{i}"
		i+=1
	root="#{mergedir}/#{name}-#{i}"
	
	-- merge layers
	ensuredir root
	if #list==1
		-- a merge with a single layer can be done with a bind
		runorerror 'mount', '-o', 'bind', list[1].rootfs, root
		State\use 'layer', list[1].root
	else
		local options
		if list[#list].writable
			options="lowerdir=#{table.concat [list[i].rootfs for i=#list-1, 1, -1], ':'},upperdir=#{list[#list].rootfs},workdir=#{list[#list].workdir}"
		else
			options="lowerdir=#{table.concat [list[i].rootfs for i=#list, 1, -1], ':'}"
		runorerror 'mount', '-t', 'overlay', 'overlay', root, '-o', options
		for layer in *list
			State\use 'layer', layer.root
	
	-- manage merge usage
	State\unusedfn 'merge', root, () ->
		umount root
		for layer in *list
			State\release 'layer', layer.root
	
	-- return our merge root
	return root

-- mount a machine entierely
-- adds one use to the merge
mountmachine= (name) ->
	-- read machine ini
	ini=getini name, machine: true
	
	-- mount all container layers
	layerdirs={}
	for layer in *ini\getlist 'machine', 'layers'
		table.insert layerdirs, mountlayer layer
	
	-- mount top layer if present
	switch ini\get 'machine', 'rootfs'
		when 'layer'
			nil -- rootfs is the layer itself
		when 'tmpfs'
			tmpfs=mounttmpfs name
			table.insert layerdirs, tmpfs
		else
			error "Illegal top layer type"
	
	-- merge layers
	rootfs=mergelayers layerdirs, name
	State\use 'merge', rootfs
	
	-- manage machine usage
	State\unusedfn 'machine', rootfs, () ->
		State\release 'merge', rootfs
	
	-- return our machine rootfs
	return rootfs

-- load default values to ini
loaddefaults= (name, ini) ->
	def= (k, v, def) ->
		if nil==ini\get k, v
			ini\set k, v, def
	def 'machine', 'hostname', name
	def 'machine', 'layers', name
	def 'machine', 'rootfs', 'layer'
	def 'machine', 'networking', 'host'
	def 'machine', 'capabilities', 'auto'
	def 'machine', 'resolv-conf', 'host'
	def 'machine', 'timezone', 'host'
	def 'machine', 'interactive', true

-- checks config file
knownvalid={}
checkconfig= (name, ini, strict=false) ->
	return if knownvalid[name]
	
	warn= (m) ->
		msg="in config for #{name}: #{m}"
		if strict=='error'
			error msg
		elseif strict=='warning'
			io.stderr\write "WARNING: #{m}\n"
	cerr= (s, k, e) ->
		error "in config for #{name}: section #{s}, key #{k}: #{e}"
	ctype= (s, k, t) ->
		a=type ini\get s, k
		cerr s, k, "type is #{a}, should be #{t}" unless a==t
	cvals= (s, k, a) ->
		r=ini\get s, k
		o=false
		for v in *a
			if r==v
				o=true
				break
		cerr s, k, "value #{r} is not allowed, should be one of #{table.concat a, ', '}" unless o
	cregm= (s, k, m) ->
		ctype s, k, 'string'
		r=ini\get s, k
		cerr s, k, "value #{r} doesn't match pattern #{m}" unless r\match m
	ctest= (fn) ->
		ok, err=pcall fn
		error "in config for #{name}: #{err}" unless ok
	clist= (s, l) ->
		m={e, true for e in *l}
		for k in pairs ini.sections[s]
			unless m[k]
				warn "invalid key #{k} in section #{s}"
	
	if ini\hassection 'layer'
		clist 'layer', {'filename', 'type', 'writable'}
		ctype 'layer', 'writable', 'boolean'
		ctype 'layer', 'filename', 'string'
		cvals 'layer', 'type', {'ext4', 'squashfs', 'directory'}
		ctest () ->
			fs="#{CONTAINER_DIR}/#{name}/#{ini\get 'layer', 'filename'}"
			if 'directory'==ini\get 'layer', 'type'
				error "directory #{fs} doesn't exist" unless isdir fs
			else
				error "file #{fs} doesn't exist" unless isfile fs
	
	if ini\hassection 'machine'
		clist 'machine', {'hostname', 'arch', 'layers', 'rootfs', 'networking', 'capabilities', 'resolv-conf', 'timezone', 'interactive'}
		ctype 'machine', 'hostname', 'string'
		ctype 'machine', 'arch', 'string'
		ctest () ->
			for layer in *ini\getlist 'machine', 'layers'
				lini=getini layer
				error "layer #{layer} has no layer" unless lini\hassection 'layer'
				unless layer==name
					loaddefaults layer, lini
					checkconfig layer, lini
		cvals 'machine', 'rootfs', {'layer', 'tmpfs'}
		cvals 'machine', 'networking', {'host', 'private'}
		cvals 'machine', 'capabilities', {'auto', 'all', 'list'}
		ctest () ->
			return unless 'list'==ini\get 'machine', 'capabilities'
			error "no capabilities section" unless ini\hassection 'capabilities'
		cvals 'machine', 'resolv-conf', {'host', 'copy', 'container'}
		cvals 'machine', 'timezone', {'host', 'copy', 'container'}
		ctype 'machine', 'interactive', 'boolean'
	
	if ini\hassection 'binds'
		for bind in pairs ini.sections.binds
			cregm 'binds', bind, '^%+?%-?/.*'
	
	if ini\hassection 'capabilities'
		warn "unused section capabilities" unless 'list'==ini\get 'machine', 'capabilities'
		for capability in pairs ini.sections.capabilities
			cvals 'capabilities', capability, {'grant', 'drop'}
	
	if ini\hassection 'networking'
		warn "unused section networking" unless 'private'==ini\get 'machine', 'networking'
		clist 'networking', {'interfaces', 'macvlan', 'ipvlan', 'veth', 'bridge', 'zone'}
	
	knownvalid[name]=true


-- creates nspawn arglist
nspawnargs= (name, ini, machine, ...) ->
	-- build the nspawn command
	args={}
	push= (arg) -> table.insert args, arg
	
	do -- use the machine rootfs
		push '-D'
		push machine
	GlobalConfig\ifallow '--console', () -> -- set machine interactivity
		push "--console=#{if ini\get 'machine', 'interactive' then 'interactive' else 'passive'}"
	GlobalConfig\ifallow '--resolv-conf', () -> -- set resolv.conf
		switch ini\get 'machine', 'resolv-conf'
			when 'host' then push '--resolv-conf=bind-host'
			when 'container' then push '--resolv-conf=off'
			when 'copy' then push '--resolv-conf=copy-host'
	GlobalConfig\ifallow '--timezone', () -> -- set timezone
		switch ini\get 'machine', 'timezone'
			when 'host' then push '--timezone=bind'
			when 'container' then push '--timezone=off'
			when 'copy' then push '--timezone=copy'
	GlobalConfig\ifallow '--hostname', () -> -- set machine hostname
		push "--hostname=#{ini\get 'machine', 'hostname'}"
	switch ini\get 'machine', 'networking' -- set machine networking
		when 'host'
			nil -- nothing to do
		when 'private'
			push '--private-network'
			for interface in *ini\getlist 'networking', 'interfaces' -- assign interfaces
				push "--network-interface=#{interface}"
			GlobalConfig\ifallow '--network-macvlan', () ->
				for macvlan in *ini\getlist 'networking', 'macvlan' -- add macvlan interfaces
					push "--network-macvlan=#{macvlan}"
			for ipvlan in *ini\getlist 'networking', 'ipvlan' -- add ipvlan interfaces
				push "--network-ipvlan=#{ipvlan}"
			GlobalConfig\ifallow '--network-veth-extra', () ->
				for veth in *ini\getlist 'networking', 'veth' -- add veth interfaces
					push "--network-veth-extra=#{veth}"
			if bridge=ini\get 'networking', 'bridge' -- add bridge interface
				push "--network-bridge=#{bridge}"
			GlobalConfig\ifallow '--network-zone', () ->
				if zone=ini\get 'networking', 'zone' -- add zone interface
					push "--network-zone=#{zone}"
	switch ini\get 'machine', 'capabilities' -- set machine capabilites
		when 'auto'
			nil -- nothing to do
		when 'all'
			push '--capability=all'
		when 'list'
			grant=[capability for capability, action in pairs ini.sections.capabilities when action=='grant']
			drop=[capability for capability, action in pairs ini.sections.capabilities when action=='drop']
			if #grant!=0
				push "--capability=#{table.concat grant, ','}"
			if #drop!=0
				push "--drop-capability=#{table.concat drop, ','}"
	if ini\hassection 'binds' -- add bind mounts
		mountpoints=[key for key in pairs ini.sections.binds]
		table.sort mountpoints
		for mountpoint in *mountpoints
			rel, ro, path=(ini\get 'binds', mountpoint)\match '^(%+?)(%-?)(.+)$'
			cmd=if ro=='-' then 'bind-ro' else 'bind'
			rel='' unless GlobalConfig\allowed 'internalbind'
			push "--#{cmd}=#{path}:#{rel}#{mountpoint}"
	for i=1, select '#', ... -- extra arguments
		push select i, ...
	return args

startmachine= (name) ->
	error "Already running" if State\machinerunning name
	
	screendir="/run/screen/S-#{preadl 'whoami'}"
	screenname="container-#{name}"
	runorerror 'screen', '-dmS', screenname, 'container', 'boot', name
	local screenpid
	for screen in *ls screendir
		local name
		pid, name=screen\match "(%d+)%.(%S+)"
		if screenname==name
			screenpid=pid
			break
	unless screenpid
		error "Screen didn't start"
	
	scriptpid=tonumber preadl 'pgrep', '-P', screenpid
	unless scriptpid
		error "Script didn't start"
	
	nspawnpid=try delay: 1, times: 5, fn: () ->
		shpid=tonumber preadl 'pgrep', '-P', scriptpid
		error! unless shpid
		pid=tonumber preadl 'pgrep', '-P', shpid
		error! unless pid
		return pid
	unless nspawnpid
		error "systemd-nspawn didn't start"
	
	initpid=try delay: 1, times: 5, fn: () ->
		pid=tonumber preadl 'pgrep', '-P', nspawnpid
		error! unless pid
		return pid
	unless initpid
		error "Init didn't start"
	
	State\addrunningmachine name, initpid
	return initpid

hasnetwork= (iface) ->
	isdir "/sys/class/net/#{iface}"

networkstate= (iface) ->
	fd=io.open "/sys/class/net/#{iface}/operstate", 'r'
	return 'unavaliable' unless fd
	state=fd\read '*l'
	fd\close!
	return state

networkaddress= (iface) ->
	lines=pread 'ip', 'addr', 'show', 'dev', iface
	v4=[addr\match "inet%s+(%d+%.%d+%.%d+%.%d+%/%d+)" for addr in *lines when addr\match "inet"]
	v6=[addr\match "inet6%s+([%da-f:]+%/%d+)" for addr in *lines when addr\match "inet6"]
	all=[a for a in *v4]
	table.insert all, a for a in *v6
	return {:v4, :v6, :all}

confignetwork= (network) ->
	section="network \"#{network}\""
	iface=GlobalConfig\get section, 'interface'
	address=GlobalConfig\get section, 'address'
	script=GlobalConfig\get section, 'script'
	error "No interface for network #{network}" unless iface
	error "No address for network #{network}" unless address
	error "Interface #{iface} not present" unless hasnetwork iface
	unless isin (networkaddress iface).all, address
		runorerror 'ip', 'addr', 'add', address, 'dev', iface
	if 'down'==networkstate iface
		runorerror 'ip', 'link', 'set', iface, 'up'
	runorerror script if script

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
		for name in pairs containers
			longestname=#name if #name>longestname
		for name, ini in pairs containers
			io.write name
			io.write string.rep ' ', (longestname-#name+1)
			if ini\hassection 'layer'
				io.write "[layer] "
			else
				io.write "        "
			if ini\hassection 'machine'
				io.write "[machine]"
			io.write "\n"
		return 0

with Command 'info'
	.args={
		{'name', required: true}
	}
	.desc="Shows container info"
	.fn=(name) ->
		-- dump container INI to stdout
		-- I could pretty-print this, but ¯\_(ツ)_/¯
		(getini name)\export!
		return 0

with Command 'checkcfg'
	.args={
		{'name', required: true}
	}
	.desc="Checks configuration of a container"
	.fn=(name) ->
		-- get container ini file
		ini=getini name
		
		-- populate default values
		loaddefaults name, ini
		checkconfig name, ini, 'warning'
		
		-- if we made it this far, the config is valid
		ini\export!
		return 0

with Command 'edit'
	.args={
		{'name', required: true}
		{'editor', required: false}
	}
	.desc="Edits a container config file"
	.fn=(name, editor) ->
		-- make sure the container exists
		getini name
		
		-- find an editor
		editor=os.getenv 'EDITOR' unless editor
		editor=os.getenv 'VISUAL' unless editor
		editor='vi' unless editor
		
		-- edit the file
		run editor, "#{CONTAINER_DIR}/#{name}/config.ini"
		return 0

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

with Command 'network-start'
	.args={
		{'name', required: true}
	}
	.desc="Sets up a network"
	.fn=(name) ->
		confignetwork name
		return 0

GlobalConfig\ifallow 'runcommand', () ->
	with Command 'run'
		.args={
			{'name', required: true}
			{'cmd', required: true}
			{'args', required: false, multiple: true}
		}
		.desc="Runs a command in a container"
		.fn=(name, cmd, ...) ->
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

with Command 'derive'
	.args={
		{'source', required: true}
		{'name', required: true}
	}
	.desc="Creates a container deriving from another container"
	.fn= (source, name) ->
		-- load container config
		ini=getini source, machine: true
		
		-- derive config file
		error "Container #{name} already exists" if isdir "#{CONTAINER_DIR}/#{name}"
		ini\set 'layer', 'filename', 'layer.dir'
		ini\set 'layer', 'type', 'directory'
		ini\set 'layer', 'writable', true
		ini\set 'machine', 'rootfs', 'layer'
		ini\append 'machine', 'layers', name
		
		-- create new container
		ensuredir "#{CONTAINER_DIR}/#{name}"
		ensuredir "#{CONTAINER_DIR}/#{name}/layer.dir"
		ini\export "#{CONTAINER_DIR}/#{name}/config.ini"
		return 0

with Command 'clone'
	.args={
		{'source', required: true}
		{'name', required: true}
	}
	.desc="Clones a container non-recursively"
	.fn= (source, name) ->
		-- load container
		ini=getini source
		State\lock 'container', source
		error "Container is in use" unless 0==State\uses 'container', source
		
		-- create destination directory
		error "Container #{name} already exists" if isdir "#{CONTAINER_DIR}/#{name}"
		ensuredir "#{CONTAINER_DIR}/#{name}"
		
		-- clone source layer if present
		if ini\hassection 'layer'
			runorerror 'cp', '-a', "#{CONTAINER_DIR}/#{source}/#{ini\get 'layer', 'filename'}", "#{CONTAINER_DIR}/#{name}"
			layers=ini\getlist 'machine', 'layers'
			for i, layer in ipairs layers
				layers[i]=name if layer==source
			ini\setlist 'machine', 'layers', layers
		
		-- write config file
		ini\export "#{CONTAINER_DIR}/#{name}/config.ini"
		State\unlock 'container', source
		return 0

with Command 'create'
	.args={
		{'name', required: true}
	}
	.desc="Creates a container with minimal config and directory layer"
	.fn= (name) ->
		-- create INI
		ini=INI!
		ini\set 'layer', 'filename', 'layer.dir'
		ini\set 'layer', 'type', 'directory'
		ini\set 'layer', 'writable', true
		ini\set 'machine', 'arch', (pread 'arch')[1]
		ini\set 'machine', 'layers', name
		
		-- create destination directories
		error "Container #{name} already exists" if isdir "#{CONTAINER_DIR}/#{name}"
		ensuredir "#{CONTAINER_DIR}/#{name}"
		ensuredir "#{CONTAINER_DIR}/#{name}/layer.dir"
		ensuredir "#{CONTAINER_DIR}/#{name}/layer.dir/rootfs"
		ensuredir "#{CONTAINER_DIR}/#{name}/layer.dir/workdir"
		
		-- write config file
		ini\export "#{CONTAINER_DIR}/#{name}/config.ini"
		return 0

with Command 'freeze'
	.args={
		{'name', required: true}
	}
	.desc="Freezes a container to squashfs"
	.fn= (name) ->
		-- mount layer
		ini=getini name, layer: true
		State\lock 'container', name
		error "Container is in use" unless 0==State\uses 'container', name
		layer=mountlayer name
		State\use 'layer', layer.root
		ok, err=pcall () ->
			runorerror 'mksquashfs', layer.rootfs, "#{CONTAINER_DIR}/#{name}/layer.squashfs", '-comp', 'xz', '-Xdict-size', '100%'
		State\release 'layer', layer.root
		oldroot="#{CONTAINER_DIR}/#{name}/#{ini\get 'layer', 'filename'}"
		error err unless ok
		ini\set 'layer', 'filename', 'layer.squashfs'
		ini\set 'layer', 'type', 'squashfs'
		ini\set 'layer', 'writable', false
		if ini\hassection 'machine'
			ini\set 'machine', 'rootfs', 'tmpfs'
		ini\export "#{CONTAINER_DIR}/#{name}/config.ini"
		runorerror 'rm', '-rf', oldroot
		State\unlock 'container', name
		return 0

with Command 'start'
	.args={
		{'name', required: true}
	}
	.desc="Starts a machine in dettached mode"
	.fn= (name) ->
		pid=startmachine name
		io.write "Machine started, init PID is #{pid}\n"
		return 0

with Command 'attach'
	.args={
		{'name', required: true}
	}
	.desc="Attaches a machine which was started in dettached mode"
	.fn= (name) ->
		error "Machine #{name} is not running" unless State\machinerunning name
		runorerror 'screen', '-r', "container-#{name}"
		return 0

with Command 'status'
	.args={
		{'name', required: false}
	}
	.desc="Shows the status of a machine, or lists all the running machines"
	.fn= (name) ->
		if name
			if State\machinerunning name
				io.write "Machine #{name} is running\n"
				return 0
			else
				io.write "Machine #{name} is not running\n"
				return 1
		else
			machines=State\runningmachines!
			unless next machines
				io.write "No machine running\n"
				return 1
			longestname=0
			for name in pairs machines
				longestname=#name if #name>longestname
			for name, pid in pairs machines
				io.write name
				io.write string.rep ' ', longestname-#name+1
				io.write pid
				io.write '\n'
			return 0

with Command 'stop'
	.args={
		{'name', required: true}
	}
	.desc="Stops a running machine"
	.fn= (name) ->
		pid=State\machinerunning name
		error "Machine #{name} is not running" unless pid
		runorerror 'kill', '-9', pid
		return 0

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

with Command 'help'
	.args={
		{'command', required: false}
	}
	.desc="Displays help for a command"
	.fn= (command) ->
		unless command
			io.write "Available commands: #{table.concat [name for name in pairs Command.commands], ", "}\n"
			return
		command=Command\get command
		io.write "#{command.desc}\n"
		io.write "#{command\usage!}\n"
		if command.help
			io.write "\n"
			io.write "#{line}\n" for line in *command.help
		else
			io.write "[no help provided]\n"
		return 0

-- make sure we run in good conditions
do
	fd=popen 'id', '-u'
	unless '0'==fd\read '*l'
		io.stderr\write "Need to run as root\n"
		os.exit 1
	fd\close!
ensuredir CONTAINER_WORKDIR

-- run the right command according to script args
fn=() -> error!
command=(table.remove arg, 1) or 'help'
cmd=Command.commands[command]
if cmd
	err=false
	for i, argtype in ipairs cmd.args
		if argtype.required and not arg[i]
			io.write "Missing required argument #{argtype[1]}\n"
			err=true
	unless err
		fn=cmd.fn
else
	io.write "No such command #{command}\n"

-- run the actual function and cleanup
ok, err=pcall fn, (table.unpack or unpack) arg
unless ok
	if err
		io.stderr\write err
		io.stderr\write '\n'
State\cleanup!
if ok
	if 'number'==type err
		os.exit err
	else
		os.exit 0
else
	os.exit 1
