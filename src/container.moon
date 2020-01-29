import popen, ensuredir from require 'exec'
require 'env'
Command=require 'Command'
State=require 'State'

-- make sure we run in good conditions
ensureroot=() ->
	fd=popen 'id', '-u'
	unless '0'==fd\read '*l'
		io.stderr\write "Need to run as root\n"
		os.exit 1
	fd\close!
ensuredir CONTAINER_WORKDIR

-- run the right command according to script args
command=(table.remove arg, 1) or 'help'
cmd=Command\get command
ensureroot! unless cmd.noroot
local ok, err
if cmd.args -- old-style commands
	fn=() -> error!
	err=false
	for i, argtype in ipairs cmd.args
		if argtype.required and not arg[i]
			io.write "Missing required argument #{argtype[1]}\n"
			err=true
	unless err
		fn=cmd.fn
	ok, err=pcall fn, (table.unpack or unpack) arg
	unless ok
		if err
			io.stderr\write err
			io.stderr\write '\n'

elseif cmd.cli -- new-style commands
	CLI=require 'CLI'
	cli=CLI cmd.cli
	local args
	ok, err=pcall ->
		args=cli\parse arg
	unless ok
		io.stderr\write err, '\n'
	else
		ok, err=pcall cmd.fn, args
		unless ok
			io.stderr\write err, '\n'

else -- uhh, wat?
	ok=false
	err=1
	io.stderr\write "Found command without args and without cli\n"

State\cleanup!
if ok
	if 'number'==type err
		os.exit err
	else
		os.exit 0
else
	os.exit 1
