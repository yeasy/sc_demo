#!/bin/sh
#Clear the vms, nets, routers, tenants, etc. created by demo_init.sh
#In theory, the script is safe to be executed repeatedly.

## THOSE VARIABLES CAN BE CUSTOMIZED. ##

# Environment information
#CONTROL_IP=192.168.122.100
#export OS_AUTH_URL=http://${CONTROL_IP}:35357/v2.0/

source ~/keystonerc_admin

# The tenant, user, net, etc... to be created
TENANT_NAME="project_one"
USER_NAME="user"
USER_PWD="user"
IMAGE_NAME="ISNP_XGS"
VM_NAME="xgs"
ROUTER_NAME="router"

## DO NOT MODIFY THE FOLLOWING PART, UNLESS YOU KNOW WHAT IT MEANS. ##
echo_r () {
    [ $# -ne 1 ] && return 0
    echo -e "\033[31m$1\033[0m"
}
echo_g () {
    [ $# -ne 1 ] && return 0
    echo -e "\033[32m$1\033[0m"
}
echo_y () {
    [ $# -ne 1 ] && return 0
    echo -e "\033[33m$1\033[0m"
}
echo_b () {
    [ $# -ne 1 ] && return 0
    echo -e "\033[34m$1\033[0m"
}
#subnet_name
get_subnetid_by_name () {
    [ $# -ne 1 ] && return 0
    local NAME=$1
    [ -z "`neutron subnet-list|grep ${NAME}`" ] && return 0
    echo `neutron subnet-list|grep ${NAME}|awk '{print $2}'`
}
#net_name
get_netid_by_name () {
    [ $# -ne 1 ] && return 0
    local NAME=$1
    [ -z "`neutron net-list|grep ${NAME}`" ] && return 0
    echo `neutron net-list|grep ${NAME}|awk '{print $2}'`
}
#subnet_name
get_subnetid_by_name () {
    [ $# -ne 1 ] && return 0
    local NAME=$1
    [ -z "`neutron subnet-list|grep ${NAME}`" ] && return 0
    echo `neutron subnet-list|grep ${NAME}|awk '{print $2}'`
}

#net_name, subnet_name
delete_net_subnet () {
    [ $# -ne 2 ] && echo "Wrong parameter number is given" && exit -1
    local NET_NAME=$1
    local SUBNET_NAME=$2
    [ -n "`neutron subnet-list|grep ${SUBNET_NAME}`" ] && neutron subnet-delete $(get_subnetid_by_name ${SUBNET_NAME})
    [ -n "`neutron net-list|grep ${NET_NAME}`" ] && neutron net-delete $(get_netid_by_name ${NET_NAME})
}

export OS_TENANT_NAME=${TENANT_NAME}
export OS_USERNAME=${USER_NAME}
export OS_PASSWORD=${USER_PWD}

echo_g "Check the xgs vm..."
if [ -n "`nova list|grep ${VM_NAME}`" ]; then
    VM_ID=`nova list|grep ${VM_NAME}|awk '{print $2}'`
    echo_g "Deleting the xgs vm..."
    nova delete ${VM_ID}
    sleep 4;
fi

source ~/keystonerc_admin

echo_g "Check the router interfaces..."
ROUTER_ID=`neutron router-list|grep ${ROUTER_NAME}|awk '{print $2}'`
INF_ID=$(get_subnetid_by_name private-subnet1)
if [ -n "${ROUTER_ID}" -a -n "${INF_ID}" ]; then 
    echo"Deleting its interface from the private1 subnet..."
    neutron router-interface-delete ${ROUTER_ID} ${INF_ID}
fi

echo_g "Clear the xgs nets and subnets..."
delete_net_subnet "private1" "private-subnet1"
delete_net_subnet "private2" "private-subnet2"
delete_net_subnet "private3" "private-subnet3"
delete_net_subnet "private4" "private-subnet4"

echo_g "Done"
