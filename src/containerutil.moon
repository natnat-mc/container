require 'env'
INI=require 'INI'
State=require 'State'
GlobalConfig=require 'GlobalConfig'
import try, isin from require 'util'
import runorerror, ls, umount, mounted, ensuredir, isdir, isfile, pread, preadl, run from require 'exec'

local getini, getallini, mountlayer, mounttmpfs, mergelayers, mountmachine, loaddefaults, checkconfig, nspawnargs, startmachine, hasnetwork, networkstate, confignetwork, networkaddress

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
	if ini\hassection 'machine'
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
	runorerror 'screen', '-dmS', screenname, arg[0], 'boot', name
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

	ini=getini name
	startcommand=ini\get 'machine', 'startcommand'
	run startcommand\gsub '%$PID', initpid if startcommand
	startnetwork=ini\getlist 'machine', 'startnetwork'
	for net in *startnetwork
		pcall confignetwork, net

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

{
	:getini, :getallini
	:mountlayer, :mounttmpfs, :mergelayers, :mountmachine
	:loaddefaults, :checkconfig
	:nspawnargs, :startmachine
	:hasnetwork, :networkstate, :networkaddress, :confignetwork
}
