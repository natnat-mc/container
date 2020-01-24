require 'env'

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

{
	:run, :runorerror
	:popen, :pread, :preadl
	:exists, :isfile, :isdir, :ls
	:mkdir, :ensuredir
	:mounted, :umount
	:getsystemdversion
}
