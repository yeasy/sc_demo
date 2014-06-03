#!/bin/sh
#Clear the vms, nets, routers, tenants, etc. created by demo_init.sh
#In theory, the script is safe to be executed repeatedly.

## THOSE VARIABLES CAN BE CUSTOMIZED. ##

# Environment information
#CONTROL_IP=192.168.122.100
#export OS_AUTH_URL=http://${CONTROL_IP}:35357/v2.0/

[ ! -e header.sh ] && echo_r "Not found header file" && exit -1
. ./header.sh

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
