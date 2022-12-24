 #!/bin/bash -i

set -e

source ~/.bash_profile
# import cli cmd functions
source utils/cli_helper.sh

######
## Function that setup an EC2 instances with for mysql, proxy and gatekeeper
# GLOBALS: 
# 	SUBNETS_1 : The used subnet Id
#   INSTANCE_ID : The generated instance Id  
#   INSTANCE_DNS : The generated EC2 Dns  
#   PRIVATE_IP :  The generated EC2 private IP
# OUTPUTS: 
# 	The instances private IPs and DNS with all needed setup
######
function setup {
    if [[ -f "backup.txt" ]]; then
        rm -f keypair.pem backup.txt master_status.txt
    fi

    #Setup network security
    create_security_group
    create_keypair

    #Setup EC2 instances
    SUBNETS_1=$(aws ec2 describe-subnets --query "Subnets[0].SubnetId" --output text)

    echo "Launch master instance..."
    MASTER_INSTANCE_ID=$(launch_ec2_instance $SUBNETS_1 "t2.micro" "config/mysql/cluster/master_setup.txt") 
    #Save the returned InstanceId as backup 
    echo "MASTER_INSTANCE_ID=\"$MASTER_INSTANCE_ID\"" >>backup.txt  

    echo "Launch standalone instance..."
    STANDALONE_INSTANCE_ID=$(launch_ec2_instance $SUBNETS_1 "t2.micro" "config/mysql/standalone/standalone_setup.txt")  
    #Save the returned InstanceId as backup 
    echo "STANDALONE_INSTANCE_ID=\"$STANDALONE_INSTANCE_ID\"" >>backup.txt

    echo "Waiting for master and standalone instances to complete initialization...."
    aws ec2 wait instance-status-ok --instance-ids ${MASTER_INSTANCE_ID} ${STANDALONE_INSTANCE_ID}

    #Retrieve master private ip and dns
    MASTER_PRIVATE_IP=$(get_ec2_private_Ip $MASTER_INSTANCE_ID)
    #Insatnce DNS will be used for ssh 
    STANDALONE_INSTANCE_DNS=$(get_ec2_public_dns $STANDALONE_INSTANCE_ID)
    MASTER_INSTANCE_DNS=$(get_ec2_public_dns $MASTER_INSTANCE_ID)
    
    #Save the returned IP and DNS as backup 
    echo "MASTER_PRIVATE_IP=\"$MASTER_PRIVATE_IP\"" >>backup.txt 
    echo "STANDALONE_INSTANCE_DNS=\"$STANDALONE_INSTANCE_DNS\"" >>backup.txt
    echo "MASTER_INSTANCE_DNS=\"$MASTER_INSTANCE_DNS\"" >>backup.txt
    
    ##########################
    ## Slaves setup
    ##########################

    echo "Check master node status and get master log_file and log_pos"
    #Retrieve master node status
    ssh -o "StrictHostKeyChecking no" -i keypair.pem ubuntu@$MASTER_INSTANCE_DNS 'bash -s' < config/mysql/show_master.sh 1>> master_status.txt
    MASTER_STATUS=$(cat master_status.txt | awk '{print $1 " " $2}')
    LOG_FILE=$(echo $MASTER_STATUS | cut -f1 -d ' ')
    LOG_POS=$(echo $MASTER_STATUS | cut -f2 -d ' ') 
    echo "Done"

    #Inject variables (MASTER_PRIVATE_IP and master status) to slave1 config
    sed -i '3i MASTER_IP='$MASTER_PRIVATE_IP'' config/mysql/cluster/slave1_setup.txt
    sed -i '4i LOG_FILE='$LOG_FILE'' config/mysql/cluster/slave1_setup.txt
    sed -i '5i LOG_POS='$LOG_POS'' config/mysql/cluster/slave1_setup.txt
    #Inject variables (MASTER_PRIVATE_IP and master status) to slave1 config
    sed -i '3i MASTER_IP='$MASTER_PRIVATE_IP'' config/mysql/cluster/slave2_setup.txt
    sed -i '4i LOG_FILE='$LOG_FILE'' config/mysql/cluster/slave2_setup.txt
    sed -i '5i LOG_POS='$LOG_POS'' config/mysql/cluster/slave2_setup.txt
    #Inject variables (MASTER_PRIVATE_IP and master status) to slave1 config
    sed -i '3i MASTER_IP='$MASTER_PRIVATE_IP'' config/mysql/cluster/slave3_setup.txt
    sed -i '4i LOG_FILE='$LOG_FILE'' config/mysql/cluster/slave3_setup.txt
    sed -i '5i LOG_POS='$LOG_POS'' config/mysql/cluster/slave3_setup.txt

    echo "Launch slaves instance..."
    SALVE1_INSTANCE_ID=$(launch_ec2_instance $SUBNETS_1 "t2.micro" "config/mysql/cluster/slave1_setup.txt")
    SALVE2_INSTANCE_ID=$(launch_ec2_instance $SUBNETS_1 "t2.micro" "config/mysql/cluster/slave2_setup.txt")
    SALVE3_INSTANCE_ID=$(launch_ec2_instance $SUBNETS_1 "t2.micro" "config/mysql/cluster/slave3_setup.txt")
    echo "Done"
    
    #Save the returned InstanceId as backup 
    echo "SALVE1_INSTANCE_ID=\"$SALVE1_INSTANCE_ID\"" >>backup.txt 
    echo "SALVE2_INSTANCE_ID=\"$SALVE2_INSTANCE_ID\"" >>backup.txt
    echo "SALVE3_INSTANCE_ID=\"$SALVE3_INSTANCE_ID\"" >>backup.txt

    echo "Waiting for slaves instances to complete initialization...."
    aws ec2 wait instance-status-ok --instance-ids ${SALVE1_INSTANCE_ID} ${SALVE2_INSTANCE_ID} ${SALVE3_INSTANCE_ID}

    #Retrieve salves private ip
    SLAVE1_PRIVATE_IP=$(get_ec2_private_Ip $SALVE1_INSTANCE_ID)
    SLAVE2_PRIVATE_IP=$(get_ec2_private_Ip $SALVE2_INSTANCE_ID)
    SLAVE3_PRIVATE_IP=$(get_ec2_private_Ip $SALVE3_INSTANCE_ID)

    echo "SLAVE1_PRIVATE_IP=\"$SLAVE1_PRIVATE_IP\"" >>backup.txt
    echo "SLAVE2_PRIVATE_IP=\"$SLAVE2_PRIVATE_IP\"" >>backup.txt
    echo "SLAVE3_PRIVATE_IP=\"$SLAVE3_PRIVATE_IP\"" >>backup.txt

    ##########################
    ## Proxy setup
    ##########################
    echo "Launch proxy instance..."
    PROXY_INSTANCE_ID=$(launch_ec2_instance $SUBNETS_1 "t2.large" "config/proxy/proxy_setup.txt") 
    #Save the returned InstanceId as backup 
    echo "PROXY_INSTANCE_ID=\"$PROXY_INSTANCE_ID\"" >>backup.txt  

    echo "Waiting for proxy instance to complete initialization...."
    aws ec2 wait instance-status-ok --instance-ids ${PROXY_INSTANCE_ID}
    
    #Retrieve the proxy DNS and private ip
    PROXY_PRIVATE_IP=$(get_ec2_private_Ip $PROXY_INSTANCE_ID)
    PROXY_INSTANCE_DNS=$(get_ec2_public_dns $PROXY_INSTANCE_ID)

    echo "PROXY_PRIVATE_IP=\"$PROXY_PRIVATE_IP\"" >>backup.txt
    echo "PROXY_INSTANCE_DNS=\"$PROXY_INSTANCE_DNS\"" >>backup.txt

    #Upload needed script in proxy instance
    scp -o "StrictHostKeyChecking no"  -i keypair.pem proxy/proxy.py ubuntu@$PROXY_INSTANCE_DNS:/home/ubuntu

    #Pass needed environement variables to proxy deploy script
    sed -i '4i MASTER_PRIVATE_IP='$MASTER_PRIVATE_IP'' proxy/deploy.sh
    sed -i '5i SLAVE1_PRIVATE_IP='$SLAVE1_PRIVATE_IP'' proxy/deploy.sh
    sed -i '6i SLAVE2_PRIVATE_IP='$SLAVE2_PRIVATE_IP'' proxy/deploy.sh
    sed -i '7i SLAVE3_PRIVATE_IP='$SLAVE3_PRIVATE_IP'' proxy/deploy.sh

    #Deploy the proxy on the instance using cluster private IPs
    ssh -o "StrictHostKeyChecking no"  -i keypair.pem ubuntu@$PROXY_INSTANCE_DNS 'bash -s' < proxy/deploy.sh

    ##########################
    ## Gatekeeper setup
    ##########################
    echo "Launch gatekeeper instance..."
    GATEKEEPER_INSTANCE_ID=$(launch_ec2_instance $SUBNETS_1 "t2.large" "config/gatekeeper/gatekeeper_setup.txt") 
    #Save the returned InstanceId as backup 
    echo "GATEKEEPER_INSTANCE_ID=\"$GATEKEEPER_INSTANCE_ID\"" >>backup.txt  

    echo "Waiting for gatekeeper instance to complete initialization...."
    aws ec2 wait instance-status-ok --instance-ids ${GATEKEEPER_INSTANCE_ID}

    #Retrieve the proxy DNS
    GATEKEEPER_INSTANCE_DNS=$(get_ec2_public_dns $GATEKEEPER_INSTANCE_ID)
    echo "GATEKEEPER_INSTANCE_DNS=\"$GATEKEEPER_INSTANCE_DNS\"" >>backup.txt

    #Upload needed script in gatekeeper instance
    scp -o "StrictHostKeyChecking no"  -i keypair.pem gatekeeper/gatekeeper.py ubuntu@$GATEKEEPER_INSTANCE_DNS:/home/ubuntu

    #Pass needed environement variables to gatekeeper deploy script
    sed -i '4i PROXY_PRIVATE_IP='$PROXY_PRIVATE_IP'' gatekeeper/deploy.sh

    #Deploy the gatekeeper on the instance
    ssh -o "StrictHostKeyChecking no"  -i keypair.pem ubuntu@$GATEKEEPER_INSTANCE_DNS 'bash -s' < gatekeeper/deploy.sh 
    
    echo "Setup Completed"

}

####################################################################################
## Function that start mysql (standalone/cluster) benchmarking using sysbench
# OUTPUTS: 
# 	Graph bar metrics
####################################################################################
function benchmarking {
    echo "\nStart benchmarking for mysql standalone ....."
    ssh -o "StrictHostKeyChecking no" -i keypair.pem ubuntu@$STANDALONE_INSTANCE_DNS 'bash -s' < benchmarking/sysbench.sh 2>> benchmarking/standalone_result.txt

    echo "Start benchmarking for mysql cluster ......" 
    ssh -o "StrictHostKeyChecking no" -i keypair.pem ubuntu@$MASTER_INSTANCE_DNS 'bash -s' < benchmarking/sysbench.sh 2>> benchmarking/cluster_result.txt

    local standalone_latency=$(grep -w Latency benchmarking/standalone_result.txt  -A 3  | awk '{print $2 }' | sed -n '3p')
    local cloud_latency=$(grep -w Latency benchmarking/cluster_result.txt  -A 3  | awk '{print $2 }' | sed -n '3p')

    python3 visualisation/display_result.py $standalone_latency $cloud_latency
    echo "Benchamarking completed"

}

######
## Function that make queries with mysql through a dns gatekeeper
# OUTPUTS: 
# 	Graph bar metrics
######
function client {
    echo "\nSend queries to cluster through gatekeeper and proxy"
    python3 client/client.py $GATEKEEPER_INSTANCE_DNS
}


######
## Function that wipe all the setup on AWS
# OUTPUTS: 
# 	Terminate the instances
#   Delete the keypair
#   Delete the security group 
######
function wipe {
    ## Terminate the ec2 instances
    if [[ -n "${STANDALONE_INSTANCE_ID}" ]]; then
        echo "Terminate the ec2 instance..."
        aws ec2 terminate-instances --instance-ids $STANDALONE_INSTANCE_ID $MASTER_INSTANCE_ID $SALVE1_INSTANCE_ID $SALVE2_INSTANCE_ID $SALVE3_INSTANCE_ID $PROXY_INSTANCE_ID $GATEKEEPER_INSTANCE_ID
        ## Wait for instances to enter 'terminated' state
        echo "Wait for instances to enter terminated state..."
        aws ec2 wait instance-terminated --instance-ids $STANDALONE_INSTANCE_ID $MASTER_INSTANCE_ID $SALVE1_INSTANCE_ID $SALVE2_INSTANCE_ID $SALVE3_INSTANCE_ID $PROXY_INSTANCE_ID $GATEKEEPER_INSTANCE_ID
        echo "instance terminated"
    fi

    # Delete Key pair
    if [[ -f "backup.txt" ]]; then
        ## Delete key pair
        echo "Delete key pair..."
        aws ec2 delete-key-pair --key-name keypair
        rm -f keypair.pem
        echo "key pair Deleted"
    fi    

    ## Delete custom security group
    if [[ -n "$SECURITY_GROUP_ID" ]]; then
        echo "Delete custom security group..."
        delete_security_group $SECURITY_GROUP_ID
        echo "Security-group deleted"
    fi
}


############
### Main
############
setup
benchmarking
client
wipe