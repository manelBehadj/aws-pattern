#!/bin/bash -i

sudo -i

cd /home/ubuntu

#Get master status
mysql -Bse "SHOW MASTER STATUS;"; 1>&2
