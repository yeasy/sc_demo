#!/bin/sh
#Clear the vms, nets, routers, tenants, etc. created by demo_init.sh
#In theory, the script is safe to be executed repeatedly.

## THOSE VARIABLES CAN BE CUSTOMIZED. ##

# Environment information
#CONTROL_IP=192.168.122.100
#export OS_AUTH_URL=http://${CONTROL_IP}:35357/v2.0/

[ ! -e ~/keystonerc_admin ] && echo_r "Not found keystonerc_admin at home directory" && exit -1
source ~/keystonerc_admin

# The tenant, user, net, etc... to be created
TENANT_NAME="IPSaaS"
TENANT_DESC="The IPSaaS project"
USER_NAME="user"
USER_PWD="user"

IMG_XGS_NAME="ISNP_XGS"
IMG_XGS_INITED_NAME="ISNP_XGS_INITED"
VM_XGS_NAME="xgs"

NET_XGS1="xgs_manage_net1"
NET_XGS2="xgs_manage_net2"
NET_XGS3="xgs_data_net1"
NET_XGS4="xgs_data_net2"
SUBNET_XGS1="xgs_manage_subnet1"
SUBNET_XGS2="xgs_manage_subnet2"
SUBNET_XGS3="xgs_data_subnet1"
SUBNET_XGS4="xgs_data_subnet2"

NET_INT1="user_$NET_INT1"
NET_INT2="user_$NET_INT2"
SUBNET_INT1="user_$SUBNET_INT1"
SUBNET_INT2="user_$SUBNET_INT2"

ROUTER_NAME="router"

IMG_USER_NAME="cirros-0.3.0-x86_64"
VM_USER_NAME1="user_cirros1"
VM_USER_NAME2="user_cirros2"

## DO NOT MODIFY THE FOLLOWING PART, UNLESS YOU KNOW WHAT IT MEANS ##
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

#vm_name
delete_vm () {
    [ $# -ne 1 ] && echo "Wrong parameter number is given" && exit -1
    local NAME=$1
    if [ -n "`nova list|grep ${NAME}`" ]; then
        local ID=`nova list|grep ${NAME}|awk '{print $2}'`
        echo_g "Deleting the vm $NAME..."
        nova delete ${ID}
        sleep 2;
    fi
}

#image_name
delete_image () {
    [ $# -ne 1 ] && echo "Wrong parameter number is given" && exit -1
    local NAME=$1
    if [ -n "`nova image-list|grep ${NAME}`" ]; then
        local ID=`nova image-list|grep ${NAME}|awk '{print $2}'`
        glance -f image-delete ${ID}
        sleep 1;
    fi
}

export OS_TENANT_NAME=${TENANT_NAME}
export OS_USERNAME=${USER_NAME}
export OS_PASSWORD=${USER_PWD}

## MAIN PROCESSING START ##

echo_b ">>>Starting the IPSaaS clean..."

echo_b "Deleting the user vms..."
delete_vm ${VM_USER_NAME1}
delete_vm ${VM_USER_NAME2}

echo_b "Deleting the xgs vm..."
delete_vm ${VM_XGS_NAME}

source ~/keystonerc_admin

echo_b "Clear the images from glance and the flavor..."
#delete_image ${IMG_USER_NAME}
#delete_image ${IMG_XGS_NAME}
#delete_image ${IMG_XGS_INITED_NAME}
[ -n "`nova flavor-list|grep ex.xgs`" ] && nova flavor-delete ex.xgs
[ -n "`nova flavor-list|grep ex.tiny`" ] && nova flavor-delete ex.tiny
[ -n "`nova flavor-list|grep ex.small`" ] && nova flavor-delete ex.small

echo_b "Deleting the router and its interfaces..."
ROUTER_ID=`neutron router-list|grep ${ROUTER_NAME}|awk '{print $2}'`
SUBNET_ID1=$(get_subnetid_by_name ${SUBNET_INT1})
SUBNET_ID2=$(get_subnetid_by_name ${SUBNET_INT2})
if [ -n "${ROUTER_ID}" -a -n "${SUBNET_ID1}" -a -n "${SUBNET_ID2}" ]; then 
    echo_g "Deleting its interface from the ${SUBNET_INT1}..."
    neutron router-interface-delete ${ROUTER_ID} ${SUBNET_ID1}
    echo_g "Deleting its interface from the ${SUBNET_INT2}..."
    neutron router-interface-delete ${ROUTER_ID} ${SUBNET_ID2}
    echo_g "Deleting router ${ROUTER_NAME}..."
    neutron router-delete ${ROUTER_ID}
fi

echo_b "Clearing the user nets and subnets..."
delete_net_subnet ${NET_INT1} ${SUBNET_INT1}
delete_net_subnet ${NET_INT2} ${SUBNET_INT2}

echo_b "Clearing the xgs nets and subnets..."
delete_net_subnet ${NET_XGS1} ${SUBNET_XGS1}
delete_net_subnet ${NET_XGS2} ${SUBNET_XGS2}
delete_net_subnet ${NET_XGS3} ${SUBNET_XGS3}
delete_net_subnet ${NET_XGS4} ${SUBNET_XGS4}

echo "Clearing the user..."
if [ -n "`keystone user-list|grep ${USER_NAME}`" ]; then 
    USER_ID=`keystone user-list|grep ${USER_NAME}|awk '{print $2}'`
    keystone user-delete ${USER_ID}
fi

echo "Clearing the project..."
if [ -n "`keystone tenant-list|grep ${TENANT_NAME}`" ]; then 
    TENANT_ID=`keystone tenant-list|grep ${TENANT_NAME}|awk '{print $2}'`
    keystone tenant-delete ${TENANT_ID}
fi

echo "Clean all generated network namespace"
for name in `ip netns show`  
do   
    [[ $name == qdhcp-* || $name == qrouter-* ]] &&  ip netns del $name
done

unset OS_TENANT_NAME
unset OS_USERNAME
unset OS_PASSWORD
unset OS_AUTH_URL
echo_g "<<<Done" && exit 0
