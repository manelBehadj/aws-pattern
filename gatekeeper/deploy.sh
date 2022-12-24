#!/bin/bash

sudo -i

cd /home/ubuntu

# Start gatekeeper server
nohup python3 gatekeeper.py $PROXY_PRIVATE_IP  > log.txt 2>&1 &