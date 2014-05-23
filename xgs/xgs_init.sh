#!/bin/sh
#Follow the steps at https://w3-connections.ibm.com/wikis/home?lang=en-us#!/wiki/Stefan's%20Corner/page/Havana%20--%20XGSPlugin%20Installation%20Instructions%20V1
#https://w3-connections.ibm.com/wikis/home?lang=en-us#!/wiki/Stefan's%20Corner/page/IceHouse%20--%20XGSPlugin%20Installation%20Instructions

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


## THOSE VARIABLES CAN BE CUSTOMIZED. ##

# Environment information
#CONTROL_IP=192.168.122.100
#export OS_AUTH_URL=http://${CONTROL_IP}:35357/v2.0/
#export OS_TENANT_NAME=admin
#export OS_USERNAME=admin
#export OS_PASSWORD=admin
[ ! -e ~/keystonerc_admin ] && echo_r "Not found keystonerc_admin at home directory" && exit -1
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
IMAGE_FILE=ISNP_5.2_20140502-1219_personal_compat.qcow2
IMAGE_INITED_NAME="ISNP_XGS_INITED"
IMAGE_INITED_FILE=ISNP_5.2_20140502-1219_personal_compat_inited.qcow2
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


echo_g ">>>Starting the XGS initialization..."

echo_g "Checking the vm image..."
[ ! -f ${IMAGE_FILE} ] && echo_r "vm image ${IMAGE_FILE} not found" exit -1;

echo_g "Checking tenant ${TENANT_NAME}"
[ -z "`keystone tenant-list|grep ${TENANT_NAME}`" ] && keystone tenant-create --name ${TENANT_NAME} --description "${TENANT_DESC}"
TENANT_ID=`keystone tenant-list|grep ${TENANT_NAME}|awk '{print $2}'`
echo "tenant id = ${TENANT_ID}"

echo_g "Checking user and try to add it into the tenant..."
[ -z "`keystone user-list|grep ${USER_NAME}`" ] && keystone user-create --name ${USER_NAME} --pass ${USER_PWD} --tenant-id ${TENANT_ID} --email ${USER_EMAIL}
USER_ID=`keystone user-list|grep ${USER_NAME}|awk '{print $2}'`
if [ -n "`keystone role-list|grep ${USER_ROLE}`" ]; then
    ROLE_ID=`keystone role-list|grep ${USER_ROLE}|awk '{print $2}'`
elif [ -n "`keystone role-list|grep ${USER_ROLE2}`" ]; then
    ROLE_ID=`keystone role-list|grep ${USER_ROLE2}|awk '{print $2}'`
else
    echo_r "No role is found"
    exit -1;
fi
[ -z "`keystone user-role-list --tenant-id ${TENANT_ID} --user-id ${USER_ID}|grep ${ROLE_ID}`" ] && keystone user-role-add --tenant-id ${TENANT_ID} --user-id ${USER_ID} --role-id ${ROLE_ID}

echo_g "Creating 4 nets and subnets"
create_net_subnet "private1" "private-subnet1" "10.0.1.0/24" "10.0.1.1"
create_net_subnet "private2" "private-subnet2" "10.0.2.0/24" "10.0.2.1"
create_net_subnet "private3" "private-subnet3" "10.0.3.0/24" "10.0.3.1"
create_net_subnet "private4" "private-subnet4" "10.0.4.0/24" "10.0.4.1"

echo_g "Checking the router, add its interface to the private1 subnet..."
[ -z "`neutron router-list|grep ${ROUTER_NAME}`" ] && neutron router-create --tenant-id ${TENANT_ID} ${ROUTER_NAME}
ROUTER_ID=`neutron router-list|grep ${ROUTER_NAME}|awk '{print $2}'`
INF_ID=$(get_subnetid_by_name private-subnet1)
if [ -n "${ROUTER_ID}" -a -n "${INF_ID}" ]; then 
    echo "Adding its interface into the private1 subnet..."
    neutron router-interface-add ${ROUTER_ID} ${INF_ID}
fi

echo_g "Adding the image file into glance..."
if [ -f ${IMAGE_FILE} -a -z "`glance image-list|grep ${IMAGE_NAME}`" ]; then
    echo "Creating glance image ${IMAGE_NAME}"
    glance image-create --disk-format qcow2 --container-format bare --name ${IMAGE_NAME} --is-public True --file ${IMAGE_FILE} --progress
    glance image-update --property hw_disk_bus=ide --property hw_vif_model=rtl8139 ${IMAGE_NAME}
    sleep 1
fi
if [ -f ${IMAGE_INITED_FILE} -a -z "`glance image-list|grep ${IMAGE_INITED_NAME}`" ]; then
    echo "Creating glance image ${IMAGE_INITED_NAME}"
    glance image-create --disk-format qcow2 --container-format bare --name ${IMAGE_INITED_NAME} --is-public True --file ${IMAGE_INITED_FILE} --progress
    glance image-update --property hw_disk_bus=ide --property hw_vif_model=rtl8139 ${IMAGE_INITED_NAME}
    sleep 1
fi
IMAGE_ID=`glance image-list|grep ${IMAGE_NAME}|awk '{print $2}'`
[ -z "${IMAGE_ID}" ] && echo_r "image ${IMAGE_NAME} is not found in glance" && exit -1

echo_g "Creating new flavor..."
[ -z "`nova flavor-list|grep tmp.xgs`" ] && nova flavor-create --is-public true tmp.xgs 20 1024 10 1

#change to user and add security rules, then start a vm
export OS_TENANT_NAME=${TENANT_NAME}
export OS_USERNAME=${USER_NAME}
export OS_PASSWORD=${USER_PWD}

echo_g "Booting the vm..."
nova boot ${VM_NAME} --image ${IMAGE_ID} --flavor 20 --availability-zone az1 \
--nic net-id=$(get_netid_by_name private1) \
--nic net-id=$(get_netid_by_name private2) \
--nic net-id=$(get_netid_by_name private3) \
--nic net-id=$(get_netid_by_name private4)

sleep 2;

unset OS_TENANT_NAME
unset OS_USERNAME
unset OS_PASSWORD
unset OS_AUTH_URL
echo_g "<<<Done" && exit 0
