#!/bin/bash

cmd=$1
name=$2

source aws_conf.sh
if [ $cmd == "create" ]
then
    #create a new ssh key pair
    #nova keypair-add --key-type ssh key-$name > key-$name.pem
    /usr/bin/rm key-*.pem -f
    /usr/bin/rm ip_addr
    /usr/bin/rm vmInfo.zip
    /usr/bin/rm -r profile
    /usr/local/bin/aws ec2 create-key-pair --key-name key-$name --query 'KeyMaterial' --output text > key-$name.pem


    #create an instance
    #nova boot --flavor 59cd17a7-8edc-49b7-a6a3-94fe99b10419 --image 18a5fc04-39b0-49b8-ac52-3a572ed1d5c3 --security-groups default --key-name key-$name --nic net-id=7df25d88-af36-404b-9b76-7e741ea1f009 vm_$name
    #aws ec2 create-tags --resources `aws ec2 run-instances --image-id ami-0a8e9e0521e827562 --count 1 --instance-type t3.micro --key-name key-$name --security-group-ids sg-0d742a6c342a73668 --subnet-id subnet-5ce94527 | jq -r ".Instances[0].InstanceId"` --tags "Key=Name,Value=vm_$name"
    /usr/local/bin/aws ec2 run-instances \
    --image-id ami-07ba03c0e47ef76b0 \
    --instance-type t3.micro \
    --count 1 \
    --subnet-id subnet-5ce94527 \
    --key-name key-$name \
    --security-group-ids sg-0d742a6c342a73668 \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=vm-$name}]" &>/dev/null
    
    #openstack network list
    #nova flavor-list
    #nova list-secgroup vm_hui
    #nova keypair-list
    #glance image-list

    #associate floating IP
    #openstack floating ip create internet
    #TO DO!!! find public IP adress of the VM with a known name
    /usr/local/bin/aws ec2 describe-instances --filters Name=tag:Name,Values=vm-$name --query "Reservations[*].Instances[*].PublicIpAddress" --output text > ip_addr
    #/usr/bin/chmod 400 key-$name.pem
    #/usr/bin/ssh -i key-$name.pem ubuntu@$(/usr/bin/cat ip_addr) '/usr/bin/bash manager.sh'
    #openstack server add floating ip vm_$name 129.192.81.205
else
    #delete an instance
    #nova delete vm_$name
    /usr/local/bin/aws ec2 terminate-instances --instance-ids $(/usr/local/bin/aws ec2 describe-instances --filters Name=tag:Name,Values=vm-$name --query "Reservations[*].Instances[*].InstanceId" --output text) &>/dev/null
    #aws ec2 terminate-instances --instance-ids $(aws ec2 describe-instances --filters Name=tag:Name,Values=test_vm --query "Reservations[*].Instances[*].InstanceId" --output text)

    #delete key pair
    #nova keypair-delete key-$name
    /usr/local/bin/aws ec2 delete-key-pair --key-name key-$name
fi