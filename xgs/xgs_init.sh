#!/bin/sh
#Follow the steps at https://w3-connections.ibm.com/wikis/home?lang=en-us#!/wiki/Stefan's%20Corner/page/Havana%20--%20XGSPlugin%20Installation%20Instructions%20V1

## THOSE VARIABLES CAN BE CUSTOMIZED. ##

# Environment information
#CONTROL_IP=192.168.122.100
#export OS_AUTH_URL=http://${CONTROL_IP}:35357/v2.0/
#export OS_TENANT_NAME=admin
#export OS_USERNAME=admin
#export OS_PASSWORD=admin
source ~/keystonerc_admin

ADMIN_NAME=admin #the name of the default admin user
ADMIN_ID=`keystone tenant-list|grep ${ADMIN_NAME}|awk '{print $2}'`

# The tenant, user, net, etc... to be created
TENANT_NAME="project_one"
TENANT_DESC="The first project"
USER_NAME="user"
USER_PWD="user"
USER_EMAIL="user@domain.com"
USER_ROLE="_member_"
USER_ROLE2="Member"

IMAGE_NAME="ISNP_XGS"
IMAGE_FILE=ISNP_5.1.2_20131121-1829.qcow2
IMAGE_INITED_NAME="ISNP_XGS_INITED"
IMAGE_INITED_FILE=xgs_inited.qcow2
VM_NAME="xgs"

ROUTER_NAME="router"


## DO NOT MODIFY THE FOLLOWING PART, UNLESS YOU KNOW WHAT IT MEANS. ##

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


#net_name, subnet_name, ip_cidr, gateway,
create_net_subnet () {
    [ $# -ne 4 ] && echo "Wrong parameter number is given" && exit -1
    local NET_NAME=$1
    local SUBNET_NAME=$2
    local IP_CIDR=$3
    local GATEWAY=$4
    [ -z "`neutron net-list|grep ${NET_NAME}`" ] && neutron net-create --tenant-id ${TENANT_ID} ${NET_NAME}
    [ -z "`neutron subnet-list|grep ${SUBNET_NAME}`" ] && neutron subnet-create --tenant-id ${TENANT_ID} --name ${SUBNET_NAME} ${NET_NAME} ${IP_CIDR} --gateway ${GATEWAY} --dns_nameservers list=true 8.8.8.7 8.8.8.8
}

echo "Check the vm image..."
[ -f ${IMAGE_FILE} ] || exit 0;

echo "Check tenant ${TENANT_NAME}"
[ -z "`keystone tenant-list|grep ${TENANT_NAME}`" ] && keystone tenant-create --name ${TENANT_NAME} --description "${TENANT_DESC}"
TENANT_ID=`keystone tenant-list|grep ${TENANT_NAME}|awk '{print $2}'`

echo "Check user and try to add it into the tenant..."
[ -z "`keystone user-list|grep ${USER_NAME}`" ] && keystone user-create --name ${USER_NAME} --pass ${USER_PWD} --tenant-id ${TENANT_ID} --email ${USER_EMAIL}
USER_ID=`keystone user-list|grep ${USER_NAME}|awk '{print $2}'`
if [ -n "`keystone role-list|grep ${USER_ROLE}`" ]; then
    ROLE_ID=`keystone role-list|grep ${USER_ROLE}|awk '{print $2}'`
elif [ -n "`keystone role-list|grep ${USER_ROLE2}`" ]; then
    ROLE_ID=`keystone role-list|grep ${USER_ROLE2}|awk '{print $2}'`
else
    echo "No role is found"
    exit -1;
fi
[ -z "`keystone user-role-list --tenant-id ${TENANT_ID} --user-id ${USER_ID}|grep ${ROLE_ID}`" ] && keystone user-role-add --tenant-id ${TENANT_ID} --user-id ${USER_ID} --role-id ${ROLE_ID}

echo "Create nets and subnets"
create_net_subnet "private1" "private-subnet1" "10.0.1.0/24" "10.0.1.1"
create_net_subnet "private2" "private-subnet2" "10.0.2.0/24" "10.0.2.1"
create_net_subnet "private3" "private-subnet3" "10.0.3.0/24" "10.0.3.1"
create_net_subnet "private4" "private-subnet4" "10.0.4.0/24" "10.0.4.1"

echo "Check the router, add its interface to the private1 subnet..."
[ -z "`neutron router-list|grep ${ROUTER_NAME}`" ] && neutron router-create --tenant-id ${TENANT_ID} ${ROUTER_NAME}
ROUTER_ID=`neutron router-list|grep ${ROUTER_NAME}|awk '{print $2}'`
#neutron router-interface-add ${ROUTER_ID} $(get_subnetid_by_name private-subnet1)

echo "Add the image file into glance and create flavors..."
if [ -z "`glance image-list|grep ${IMAGE_NAME}`" ]; then
    glance image-create --disk-format qcow2 --container-format bare --name ${IMAGE_NAME} --is-public True --file ${IMAGE_FILE} --progress
    glance image-update --property hw_disk_bus=ide --property hw_vif_model=e1000 ${IMAGE_NAME}
    sleep 2
fi
if [ -z "`glance image-list|grep ${IMAGE_INITED_NAME}`" ]; then
    glance image-create --disk-format qcow2 --container-format bare --name ${IMAGE_INITED_NAME} --is-public True --file ${IMAGE_INITED_FILE} --progress
    glance image-update --property hw_disk_bus=ide --property hw_vif_model=e1000 ${IMAGE_INITED_NAME}
    sleep 2
fi
IMAGE_ID=`glance image-list|grep ${IMAGE_NAME}|awk '{print $2}'`
[ -z "`nova flavor-list|grep tmp.xgs`" ] && nova flavor-create --is-public true tmp.xgs 20 1024 10 1

#change to user and add security rules, then start a vm
export OS_TENANT_NAME=${TENANT_NAME}
export OS_USERNAME=${USER_NAME}
export OS_PASSWORD=${USER_PWD}

echo "Boot a vm in the internal net..."
nova boot ${VM_NAME} --image ${IMAGE_ID} --flavor 20 --availability-zone az1 \
--nic net-id=$(get_netid_by_name private1) \
--nic net-id=$(get_netid_by_name private2) \
--nic net-id=$(get_netid_by_name private3) \
--nic net-id=$(get_netid_by_name private4)

sleep 2;

echo "Done"
exit
