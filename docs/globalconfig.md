# Global config file format
Note that the global config file isn't checked for errors by the script, so edit it manually with caution

## `[blacklist]` section
This section lists blacklisted `systemd-nspawn` functionality; it is automatically generated at the first start of the script to reflect the available options, but it is never updated automatically after that.

## `[general]` section
- `logdir`: string *defaults to `/var/log/container`*  
	the log directory to use for the service and cronjob tasks
- `autostart`: list  
	the script will autostart these containers at system boot *requires service*
- `autorestart`: list  
	the script will automatically restart these containers if they stop *requires cronjob*
- `networks`: list  
	the script will manage these networks (which need to be defined in `[network "name"]` sections) at system boot *requires services* and at regular intervals *requires cronjob*

## `[network "<name>"]` sections
- `interface`: string  
	the name of the interface to monitor and configure
- `address`: list  
	a list of IPv4 and IPv6 addresses to attribute to the interface when bringing it up, in CIDR notation
- `script`: string *optional*  
	a script to run after bringing up the interface
