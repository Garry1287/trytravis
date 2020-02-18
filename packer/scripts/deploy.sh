#!/bin/bash
git clone -b monolith https://github.com/express42/reddit.git
cd reddit && bundle install
sudo mv /tmp/puma-server.service /etc/systemd/system/puma-server.service
sudo systemctl daemon-reload
sudo systemctl enable puma-server
sudo systemctl start puma-server
