#!bin/bash -i

sudo -i

cd /home/ubuntu

sysbench --db-driver=mysql --mysql-user='root' --mysql-db=sakila --table-size=10000 --threads=4 /usr/share/sysbench/oltp_read_write.lua prepare

sysbench --db-driver=mysql --mysql-user='root' --mysql-db=sakila --table-size=10000 --events=0 --time=60 --rate=50 --threads=8 --tables=1 /usr/share/sysbench/oltp_read_write.lua run 1>&2

sysbench --db-driver=mysql --mysql-db=sakila --mysql-user=root /usr/share/sysbench/oltp_read_write.lua cleanup