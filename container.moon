#!/usr/bin/env moon

VERBOSE=(os.getenv 'VERBOSE') or false

escape= (str) ->
	'\"'..str\gsub('\\', '\\\\')\gsub('\'', '\\\'')\gsub('\"', '\\\"')..'\"'

run= (prog, ...) ->
	return run prog, (table.unpack or unpack) ... if 'table'==type select 1, ...
	cmd="#{prog} #{table.concat [escape select i, ... for i=1, select '#', ...], ' '}"
	print cmd if VERBOSE
	a, b, c=os.execute cmd
	return a, c if 'boolean'==type a
	return a==0, a
runorerror= (prog, ...) ->
	error "failed to run #{prog}" unless run prog, ...

popen= (prog, ...) ->
	return popen prog, (table.unpack or unpack) ... if 'table'==type select 1, ...
	cmd="#{prog} #{table.concat [escape select i, ... for i=1, select '#', ...], ' '}"
	print cmd if VERBOSE
	io.popen cmd

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
	append: (section, key, ...) =>
		list=@getlist section, key
		table.insert list, select i, ... for i=1, select '#', ...
		@set section, key, table.concat list, ' '
	
	export: (filename) =>
		fd, err=io.open filename, 'w'
		error err unless fd
		for section, data in pairs @sections
			ok, err=fd\write "[#{section}]\n"
			error err unless ok
			for key, value in pairs data
				ok, err=fd\write "#{key} = #{value}\n"
				error err unless ok
		ok, err=fd\close!
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

CONTAINER_DIR=(os.getenv 'CONTAINER_DIR') or '/srv/containers'
CONTAINER_WORKDIR=(os.getenv 'CONTAINER_WORKDIR') or '/tmp/containerwork'

mountlayer= (name) ->
	ini=INI\parse "#{CONTAINER_DIR}/#{name}/config.ini"
	root="#{CONTAINER_WORKDIR}/layers/#{name}/mountroot"
	writable=ini\get 'layer', 'writable'
	workdir=if writable then "#{root}/workdir" else nil
	rootfs=if writable then "#{root}/rootfs" else root
	unless mounted root
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
		if writable
			ensuredir workdir if workdir
			ensuredir rootfs
	return {:root, :workdir, :rootfs, :writable}

mounttmpfs= (name) ->
	tmpfsdir="#{CONTAINER_WORKDIR}/tmpfs"
	i=0
	while isdir "#{tmpfsdir}/#{name}-#{i}"
		i+=1
	root="#{tmpfsdir}/#{name}-#{i}"
	writable=true
	workdir="#{root}/workdir"
	rootfs="#{root}/rootfs"
	ensuredir root
	runorerror 'mount', '-t', 'tmpfs', "tmpfs-#{name}", root
	ensuredir workdir
	ensuredir rootfs
	return {:root, :workdir, :rootfs, :writable}

mergelayers= (list, name) ->
	mergedir="#{CONTAINER_WORKDIR}/merge"
	i=0
	while isdir "#{mergedir}/#{name}-#{i}"
		i+=1
	root="#{mergedir}/#{name}-#{i}"
	ensuredir root
	if #list==1
		runorerror 'mount', '-o', 'bind', list[1].workdir, root
		return root
	local options
	if list[#list].writable
		options="lowerdir=#{table.concat [list[i].rootfs for i=#list-1, 1, -1], ':'},upperdir=#{list[#list].rootfs},workdir=#{list[#list].workdir}"
	else
		options="lowerdir=#{table.concat [list[i].rootfs for i=#list, 1, -1], ':'}"
	runorerror 'mount', '-t', 'overlay', 'overlay', root, '-o', options
	return root

mountmachine= (name, ini) ->
	layerdirs={}
	tmpfs=nil
	for layer in *ini\getlist 'machine', 'layers'
		table.insert layerdirs, mountlayer layer
	switch ini\get 'machine', 'rootfs'
		when 'layer'
			nil -- rootfs is the layer itself
		when 'tmpfs'
			tmpfs=mounttmpfs ini\get 'machine', 'hostname'
			table.insert layerdirs, tmpfs
		else
			error "Illegal top layer type"
	rootfs=mergelayers layerdirs, ini\get 'machine', 'hostname'
	return layerdirs, rootfs, tmpfs

help=
	general: {
		"#{arg[0]}, a layered container helper"
		"subcommands: help, list, info, boot, mount, derive, freeze"
		"env CONTAINER_DIR: the directory in which the containers are searched"
		"env CONTAINER_WORKDIR: the directory in which the containers are mounted/booted"
	}
	list: {
		"#{arg[0]} list: list all layers and containers"
	}
	info: {
		"#{arg[0]} info <layer|machine>: show layer/machine info"
	}
	boot: {
		"#{arg[0]} boot <machine>: boot an instance of a container"
		"containers with a tmpfs topmost layer can be booted multiple times"
	}
	mount: {
		"#{arg[0]} mount <machine>: mount an instance of a container"
		"this commands only mounts the container and doesn't start it or help you unmount it"
	}
	derive: {
		"#{arg[0]} derive <source> <name>: create a container deriving from `source` called `name`"
		"the new container will share the same layers as the source, plus a directory layer and the same settings as the source layer"
	}
	freeze: {
		"#{arg[0]} freeze <layer>: freeze a layer"
		"this command freezes a layer so that its fs becomes a readonly squashfs filesystem"
		"if the layer has an associated machine, the machine gets updated to use a tmpfs top layer"
	}
help=setmetatable help, {
	__call: (section='general') =>
		if @[section]
			for line in *@[section]
				io.write line
				io.write '\n'
		else
			io.stderr\write "No help found for #{section}\n"
			os.exit 1
		os.exit 0
}

list= () ->
	dirs={name, INI\parse "#{CONTAINER_DIR}/#{name}/config.ini" for name in *ls CONTAINER_DIR when isfile "#{CONTAINER_DIR}/#{name}/config.ini"}
	layers={name, ini for name, ini in pairs dirs when ini\hassection 'layer'}
	machines={name, ini for name, ini in pairs dirs when ini\hassection 'machine'}
	if next layers
		io.write "Layers:\n"
		io.write "\t#{name}: #{ini\get 'layer', 'type'} [#{if ini\get 'layer', 'writable' then 'RW' else 'RO'}]\n" for name, ini in pairs layers
	if next machines
		io.write "Machines:\n"
		io.write "\t#{name}\n" for name in pairs machines

info= (name) ->
	unless name
		io.stderr\write "Usage: #{arg[0]} info <layer|machine>\n"
		os.exit 1
	ok, ini=pcall INI\parse, "#{CONTAINER_DIR}/#{name}/config.ini"
	unless ok
		io.stderr\write ini
		io.stderr\write '\n'
		os.exit 1
	if ini\hassection 'layer'
		io.write "Layer info:\n"
		io.write "\tread/write: [#{if ini\get 'layer', 'writable' then "RW" else "RO"}]\n"
		io.write "\ttype: #{ini\get 'layer', 'type'}\n"
		io.write "\tfilename: #{ini\get 'layer', 'filename'}\n"
	if ini\hassection 'machine'
		io.write "Machine info:\n"
		io.write "\thostname: #{ini\get 'machine', 'hostname'}\n"
		io.write "\tnetworking: #{ini\get 'machine', 'networking'}\n"
		io.write "\tnetworking bridge: #{ini\get 'machine', 'network-bridge'}\n" if 'bridge'==ini\get 'machine', 'networking'
		io.write "\tnetworking zone: #{ini\get 'machine', 'network-zone'}\n" if 'zone'==ini\get 'machine', 'networking'
		io.write "\tnetwork card used: #{ini\get 'machine', 'network-card'}\n" if ('ipvlan'==ini\get 'machine', 'networking') or 'macvlan'==ini\get 'machine', 'networking'
		io.write "\trootfs: #{ini\get 'machine', 'rootfs'}\n"
		io.write "\tarch: #{ini\get 'machine', 'arch'}\n"
		io.write "\tlayers: #{table.concat (ini\getlist 'machine', 'layers'), ', '}\n"
		io.write "\textra veth: #{table.concat (ini\getlist 'machine', 'network-extra'), ', '}\n" if ini\has 'machine', 'network-extra'
		if ini\hassection 'binds'
			io.write "\tBind mounts:\n"
			keys=[k for k in pairs ini.sections.binds]
			table.sort keys
			for dest in *keys
				src=ini\get 'binds', dest
				internal='+'==src\sub 1, 1
				src=src\sub 2 if internal
				ro='-'==src\sub 1, 1
				src=src\sub 2 if ro
				io.write "\t\t#{dest}: #{src} (#{internal and "internal" or "external"}) [#{ro and "RO" or "RW"}]\n"

mount= (name) ->
	unless name
		io.stderr\write "Usage: #{arg[0]} mount <machine>\n"
		os.exit 1
	ok, ini=pcall INI\parse, "#{CONTAINER_DIR}/#{name}/config.ini"
	unless ok
		io.stderr\write ini
		io.stderr\write '\n'
		os.exit 1
	unless ini\hassection 'machine'
		io.stderr\write "Container is layer only: can't mount it\n"
		os.exit 1
	layerdirs, rootfs, tmpfs=mountmachine name, ini
	io.write "layers:\n"
	for layer in *layerdirs
		io.write "\t#{layer.root} [#{layer.writable and "RW" or "RO"}]\n"
		io.write "\t\tworkdir: #{layer.workdir}\n" if layer.workdir
		io.write "\t\trootfs: #{layer.rootfs}\n"
	if tmpfs
		io.write "tmpfs: #{tmpfs.root} [#{tmpfs.writable and "RW" or "RO"}]\n"
		io.write "\tworkdir: #{tmpfs.workdir}\n" if tmpfs.workdir
		io.write "\trootfs: #{tmpfs.rootfs}\n"
	io.write "rootfs: #{rootfs}\n"

boot= (name) ->
	unless name
		io.stderr\write "Usage: #{arg[0]} boot <machine>\n"
		os.exit 1
	ok, ini=pcall INI\parse, "#{CONTAINER_DIR}/#{name}/config.ini"
	unless ok
		io.stderr\write ini
		io.stderr\write '\n'
		os.exit 1
	unless ini\hassection 'machine'
		io.stderr\write "Container is layer only: can't boot it\n"
		os.exit 1
	layerdirs, rootfs, tmpfs=mountmachine name, ini
	nspawnargs={
		'-b'
		'-D', rootfs
		'--timezone=bind'
	}
	switch ini\get 'machine', 'networking'
		when 'passthrough'
			table.insert nspawnargs, '--resolv-conf=bind-host'
		when 'veth'
			table.insert nspawnargs, '--network-veth'
		when 'bridge'
			table.insert nspawnargs, "--network-bridge=#{ini\getorerror 'machine', 'network-bridge'}"
		when 'zone'
			table.insert nspawnargs, "--network-zone=#{ini\getorerror 'machine', 'network-zone'}"
		when 'ipvlan'
			table.insert nspawnargs, "--network-ipvlan=#{ini\getorerror 'machine', 'network-card'}"
		when 'macvlan'
			table.insert nspawnargs, "--network-macvlan=#{ini\getorerror 'machine', 'network-card'}"
		else
			error "unknown networking type #{ini\get 'machine', 'networking'}"
	if ini\hassection 'binds'
		keys=[key for key in pairs ini.sections.binds]
		table.sort keys
		for dest in *keys
			src=ini\get 'binds', dest
			internal='+'==src\sub 1, 1
			src=src\sub 2 if internal
			ro='-'==src\sub 1, 1
			src=src\sub 2 if ro
			table.insert nspawnargs, "--#{ro and 'bind-ro' or 'bind'}=#{internal and '+' or ''}#{src\gsub ':', '\\:'}:#{dest\gsub ':', '\\:'}"
	runorerror 'systemd-nspawn', nspawnargs
	umount rootfs
	umount tmpfs.root if tmpfs

derive= (source, name) ->
	error "Usage:\t#{arg[0]} derive <source> <name>" unless source and name
	ini=INI\parse "#{CONTAINER_DIR}/#{source}/config.ini"
	error "container #{name} already exists" if isdir "#{CONTAINER_DIR}/#{name}"
	error "source container must contain a machine" unless ini\hassection 'machine'
	ensuredir "#{CONTAINER_DIR}/#{name}"
	ini\set 'layer', 'filename', 'layer.dir'
	ini\set 'layer', 'type', 'directory'
	ini\set 'layer', 'writable', true
	ini\set 'machine', 'rootfs', 'layer'
	ini\append 'machine', 'layers', name
	ini\export "#{CONTAINER_DIR}/#{name}/config.ini"
	ensuredir "#{CONTAINER_DIR}/#{name}/layer.dir"

freeze= (name) ->
	error "Usage:\t#{arg[0]} freeze <name>" unless name
	dir="#{CONTAINER_DIR}/#{name}"
	ini=INI\parse "#{dir}/config.ini"
	error "no layer in container" unless ini\hassection 'layer'
	error "layer is already frozen" if 'squashfs'==ini\get 'layer', 'type'
	root="#{CONTAINER_WORKDIR}/layers/#{name}/mountroot"
	error "layer is already mounted" if mounted root
	layer=mountlayer name
	runorerror 'mksquashfs', layer.rootfs, "#{dir}/layer.squashfs", '-comp', 'xz', '-Xdict-size', '100%'
	umount layer.root
	runorerror 'rm', '-rf', "#{dir}/#{ini\get 'layer', 'filename'}"
	ini\set 'layer', 'filename', 'layer.squashfs'
	ini\set 'layer', 'type', 'squashfs'
	ini\set 'layer', 'writable', false
	if ini\hassection 'machine'
		ini\set 'machine', 'rootfs', 'tmpfs'
	ini\export "#{dir}/config.ini"


printusage= () ->
		io.stderr\write "Usage:\t#{arg[0]} <subcommand>\n"
		io.stderr\write "\t#{arg[0]} help\n"
		os.exit 1

fn=switch (table.remove arg, 1) or 'help'
	when 'help' then help
	when 'list' then list
	when 'info' then info
	when 'mount' then mount
	when 'boot' then boot
	when 'derive' then derive
	when 'freeze' then freeze
	else printusage
ok, err=pcall fn, (table.unpack or unpack) arg
unless ok
	io.stderr\write err
	io.stderr\write '\n'
	os.exit 1
