#!/bin/bash
echo "Starting SSH ..."
service ssh start

# Start oauth2-proxy in background
nohup  /opt/oauth2-proxy --custom-sign-in-logo '-' --http-address 0.0.0.0:8080 > /var/log/oauth2-proxy.log 2>&1 &

catalina.sh run
