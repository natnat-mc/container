#!/bin/sh
./make.sh
sudo install -o root -g root -m 755 container /usr/local/sbin/container
sudo install -o root -g root -m 644 container.cron /etc/cron.d/container
sudo install -o root -g root -m 644 container.service /etc/systemd/system/container.service
sudo systemctl enable container.service
