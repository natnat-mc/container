export *

VERBOSE=(os.getenv 'VERBOSE') or false
CONTAINER_DIR=(os.getenv 'CONTAINER_DIR') or '/srv/containers'
CONTAINER_WORKDIR=(os.getenv 'CONTAINER_WORKDIR') or '/tmp/containerwork'
