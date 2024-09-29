#!/bin/bash
echo "Starting SSH ..."
service ssh start

# Start oauth2-proxy in background
nohup  /opt/oauth2-proxy --custom-sign-in-logo '-' --http-address 0.0.0.0:80 > /var/log/oauth2-proxy.log &

catalina.sh run
