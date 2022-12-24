#!/bin/bash

sudo -i

cd /home/ubuntu

# Start proxy server 
nohup python3 proxy.py $MASTER_PRIVATE_IP  --slaves_ip $SLAVE1_PRIVATE_IP $SLAVE2_PRIVATE_IP $SLAVE3_PRIVATE_IP   > log.txt 2>&1 &