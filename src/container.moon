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
fn=() -> error!
command=(table.remove arg, 1) or 'help'
cmd=Command\get command
ensureroot! unless cmd.noroot
err=false
for i, argtype in ipairs cmd.args
	if argtype.required and not arg[i]
		io.write "Missing required argument #{argtype[1]}\n"
		err=true
unless err
	fn=cmd.fn

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
