#!/bin/bash
################################################
# 通过修改Docker 容器的NETNS来为容器分配IP     #
################################################
if [ $# -ne 4 ] 
then
    echo "****** Docker_Static_IP.sh CONTAINER IP MASK GATEWAY"
    echo "****** Like following calling"
    echo "****** Docker_Static_IP.sh d6627f1bfd51 192.168.1.100 24 192.168.1.1"
    exit 1
fi

CID="$1"
IP="$2"
MASK="$3"
GW="$4"

# Getting docker container's PID 
PID=$(docker inspect --format='{{.State.Pid}}' $CID)
if [ -z $PID ] 
then
    echo "****** Could not get PID of CONTAINER $CID."
    echo "****** Please check the CONTAINER ID."
    exit 1
fi

if [ ! -d /var/run/netns ] 
then
    mkdir -p /var/run/netns
fi
# Restore the network namespace info
ln -s /proc/${PID}/ns/net /var/run/netns/${PID}

# Create veth pairs for container
ip link add ${PID}.bveth0 type veth peer name ${PID}.cveth0

# Assign bveth pairs to br0
brctl addif br0 ${PID}.bveth0

# Let's bveth0 dev up 
ip link set ${PID}.bveth0 up

# Assign cveth pairs to container
ip link set ${PID}.cveth0 netns ${PID}

# Change the cveth name from ${PID}.veth0 to eth0 on container
ip netns exec ${PID} ip link set ${PID}.cveth0 name eth0

# Set up the eth0 dev on container
ip netns exec ${PID} ip link set eth0 up

# configura the ip and gw for eth0 on container
ip netns exec ${PID} ip addr add ${IP}/${MASK} dev eth0
ip netns exec ${PID} ip route add default via $GW

 
echo "All operation is done. Please using ping command to test $IP."
