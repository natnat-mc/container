#!/bin/sh
./make.sh
sudo cp container /usr/local/sbin/container
sudo chown root:root /usr/local/sbin/container
