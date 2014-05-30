#!/bin/sh
#Follow the steps at https://w3-connections.ibm.com/wikis/home?lang=en-us#!/wiki/Stefan's%20Corner/page/Havana%20--%20XGSPlugin%20Installation%20Instructions%20V1
#https://w3-connections.ibm.com/wikis/home?lang=en-us#!/wiki/Stefan's%20Corner/page/IceHouse%20--%20XGSPlugin%20Installation%20Instructions

## THOSE VARIABLES CAN BE CUSTOMIZED. ##

# Environment information
#CONTROL_IP=192.168.122.100
[ ! -e ~/keystonerc_admin ] && echo_r "Not found keystonerc_admin at home directory" && exit -1
source ~/keystonerc_admin

ADMIN_NAME=admin #the name of the default admin user
ADMIN_ID=`keystone tenant-list|grep ${ADMIN_NAME}|awk '{print $2}'`

# The tenant, user, net, etc... to be created
TENANT_NAME="IPSaaS"
TENANT_DESC="The IPSaaS project"
USER_NAME="user"
USER_PWD="user"
USER_EMAIL="user@domain.com"
USER_ROLE="_member_"
USER_ROLE2="Member"

IMG_XGS_NAME="ISNP_XGS"
IMG_XGS_FILE=ISNP_5.2_20140502-1219_personal_compat.qcow2
IMG_XGS_INITED_NAME="ISNP_XGS_INITED"
IMG_XGS_INITED_FILE=ISNP_5.2_20140502-1219_personal_compat_inited.qcow2
VM_XGS_NAME="xgs"

NET_XGS1="xgs_manage_net1"
NET_XGS2="xgs_manage_net2"
NET_XGS3="xgs_data_net1"
NET_XGS4="xgs_data_net2"
SUBNET_XGS1="xgs_manage_subnet1"
SUBNET_XGS2="xgs_manage_subnet2"

NET_INT1="user_$NET_INT1"
NET_INT2="user_$NET_INT2"
SUBNET_INT1="user_$SUBNET_INT1"
SUBNET_INT2="user_$SUBNET_INT2"

ROUTER_NAME="router"

IMG_USER_NAME="cirros-0.3.0-x86_64"
IMG_USER_FILE=cirros-0.3.0-x86_64-disk.img
IMG_USER_URL=https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img
#if not existed will download from ${IMG_USER_URL}
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

#router_name
get_routerid_by_name () {
    [ $# -ne 1 ] && return 0
    local NAME=$1
    [ -z "`neutron router-list|grep ${NAME}`" ] && return 0
    echo `neutron router-list|grep ${NAME}|awk '{print $2}'`
}

#net_name, subnet_name, ip_cidr, gateway,
create_net_subnet () {
    [ $# -ne 4 ] && echo_r "Wrong parameter number is given" && exit -1
    local NET_NAME=$1
    local SUBNET_NAME=$2
    local IP_CIDR=$3
    local GATEWAY=$4
    [ -z "`neutron net-list|grep ${NET_NAME}`" ] && neutron net-create --tenant-id ${TENANT_ID} ${NET_NAME}
    [ -z "`neutron subnet-list|grep ${SUBNET_NAME}`" ] && neutron subnet-create --tenant-id ${TENANT_ID} --name ${SUBNET_NAME} ${NET_NAME} ${IP_CIDR} --gateway ${GATEWAY} --dns_nameservers list=true 8.8.8.7 8.8.8.8
}

#tenant_name tenant_desc
#return tenant_id
create_tenant () {
    [ $# -ne 2 ] && echo_r "Wrong parameter number is given" && exit -1
    local NAME=$1
    local DESC=$2
    [ -z "`keystone tenant-list|grep ${TENANT_NAME}`" ] && keystone tenant-create --name ${NAME} --description "${DESC}"
    echo `keystone tenant-list|grep ${TENANT_NAME}|awk '{print $2}'`
}

#user_name user_pwd tenant_id user_email
create_user () {
    [ $# -ne 1 ] && echo_r "Wrong parameter number is given" && exit -1
    local NAME=$1
    local PWD=$2
    local TEN_ID=$3
    local EMAIL=$4
    [ -n "`keystone user-list|grep ${NAME}`" ] && echo_g "User is found" && exit 0
    keystone user-create --name ${NAME} --pass ${PWD} --tenant-id ${TEN_ID} --email ${EMAIL}
    [ -z "`keystone user-list|grep ${NAME}`" ] && echo_r "User creation failed" && exit -1
    local USER_ID=`keystone user-list|grep ${NAME}|awk '{print $2}'`
    if [ -n "`keystone role-list|grep ${USER_ROLE}`" ]; then
        ROLE_ID=`keystone role-list|grep ${USER_ROLE}|awk '{print $2}'`
    elif [ -n "`keystone role-list|grep ${USER_ROLE2}`" ]; then
        ROLE_ID=`keystone role-list|grep ${USER_ROLE2}|awk '{print $2}'`
    else
        echo_r "No role is found"
        exit -1;
    fi
    [ -z "`keystone user-role-list --tenant-id ${TEN_ID} --user-id ${USER_ID}|grep ${ROLE_ID}`" ] && keystone user-role-add --tenant-id ${TEN_ID} --user-id ${USER_ID} --role-id ${ROLE_ID}
    echo_g "User created with id $USER_ID"
}
#router_name tenant_id
#return router_id
create_router () {
    [ $# -ne 2 ] && echo_r "Wrong parameter number is given" && exit -1
    local NAME=$1
    local TEN_ID=$2
    [ -z "`neutron router-list|grep ${NAME}`" ] && neutron router-create --tenant-id ${TEN_ID} ${NAME}
    [ -z "`neutron router-list|grep ${NAME}`" ] && return 0
    echo `neutron router-list|grep ${NAME}|awk '{print $2}'`
}

#image_name image_file
create_image () {
    [ $# -ne 2 ] && echo_r "Wrong parameter number is given" && exit -1
    local NAME=$1
    local FILE=$2
    if [ -f ${FILE} -a -z "`glance image-list|grep ${NAME}`" ]; then
        echo "Creating glance image ${NAME}"
        glance image-create --disk-format qcow2 --container-format bare --name ${NAME} --is-public True --file ${FILE} --progress
        sleep 1
    fi
}
## MAIN PROCESSING START ##

echo_b ">>>Starting the IPSaaS initialization..."

echo_b "Checking the xgs image..."
[ ! -f ${IMG_XGS_FILE} ] && echo_r "vm image ${IMG_XGS_FILE} not found" exit -1;

echo_b "Check the demo image..."
[ -f ${IMG_USER_FILE} ] || wget ${IMG_USER_URL}

echo_b "Checking tenant ${TENANT_NAME}"
TENANT_ID=$(create_tenant $TENANT_NAME $TENANT_DESC) && echo "tenant id = ${TENANT_ID}"

echo_b "Checking user..."
create_user ${USER_NAME} ${USER_PWD} ${TENANT_ID} ${USER_EMAIL}

echo_b "Creating 4 nets and subnets for the xgs vm"
create_net_subnet "$NET_XGS1" "$NET_XGS1" "10.0.1.0/24" "10.0.1.1"
create_net_subnet "$NET_XGS2" "$NET_XGS2" "10.0.2.0/24" "10.0.2.1"
create_net_subnet "$NET_XGS3" "$XGS_SUBNET1" "10.0.3.0/24" "10.0.3.1"
create_net_subnet "$NET_XGS4" "$XGS_SUBNET2" "10.0.4.0/24" "10.0.4.1"

echo_b "Creating 2 nets and subnets for the user vm"
create_net_subnet "$NET_INT1" "$SUBNET_INT1" "192.168.1.0/24" "192.168.1.1"
create_net_subnet "$NET_INT2" "$SUBNET_INT2" "192.168.2.0/24" "192.168.2.1"

echo_b "Checking the router, add its interface between user subnet..."
ROUTER_ID=$(create_router "${ROUTER_NAME}" "${TENANT_ID}")
SUBNET_ID1=$(get_subnetid_by_name "$SUBNET_INT1")
SUBNET_ID2=$(get_subnetid_by_name "$SUBNET_INT2")
if [ -n "${ROUTER_ID}" -a -n "${SUBNET_ID1}" -a -n "${SUBNET_ID2}" ]; then 
    echo "Adding router interface into the user subnets..."
    neutron router-interface-add ${ROUTER_ID} ${SUBNET_ID1}
    neutron router-interface-add ${ROUTER_ID} ${SUBNET_ID2}
fi

echo_b "Adding the user_vm, xgs, xgs_inited image file into glance..."
create_image ${IMG_USER_NAME} ${IMG_USER_FILE}
create_image ${IMG_XGS_NAME} ${IMG_XGS_FILE}
create_image ${IMG_XGS_INITED_NAME} ${IMG_XGS_INITED_FILE}
glance image-update --property hw_disk_bus=ide --property hw_vif_model=rtl8139 ${IMG_XGS_NAME}
glance image-update --property hw_disk_bus=ide --property hw_vif_model=rtl8139 ${IMG_XGS_INITED_NAME}
IMG_XGS_ID=`glance image-list|grep ${IMG_XGS_NAME}|awk '{print $2}'`
[ -z "${IMG_XGS_ID}" ] && echo_r "image ${IMG_XGS_NAME} is not found in glance" && exit -1

echo_b "Creating new flavors..."
[ -z "`nova flavor-list|grep tmp.xgs`" ] && nova flavor-create --is-public true tmp.xgs 20 1024 10 1
[ -z "`nova flavor-list|grep ex.tiny`" ] &&nova flavor-create --is-public true ex.tiny 10 512 2 1
[ -z "`nova flavor-list|grep ex.small`" ] && nova flavor-create --is-public true ex.small 11 512 20 1

#change to user and add security rules, then start a vm
export OS_TENANT_NAME=${TENANT_NAME}
export OS_USERNAME=${USER_NAME}
export OS_PASSWORD=${USER_PWD}

echo_b "Add default secgroup rules of allowing ping and ssh..."
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
nova secgroup-add-rule default tcp 80 80 0.0.0.0/0
nova secgroup-add-rule default tcp 443 443 0.0.0.0/0

echo_b "Booting the xgs vm..."
nova boot ${VM_XGS_NAME} --image ${IMG_XGS_ID} --flavor 20 --availability-zone az1 \
--nic net-id=$(get_netid_by_name $NET_XGS1) \
--nic net-id=$(get_netid_by_name $NET_XGS2) \
--nic net-id=$(get_netid_by_name $NET_XGS3) \
--nic net-id=$(get_netid_by_name $NET_XGS4)
sleep 2;

echo_b "Booting the user vm..."
nova boot ${VM_USER_NAME1} --image ${IMG_USER_ID} --flavor 10 --nic net-id=$(get_netid_by_name "$NET_INT1")
sleep 1
nova boot ${VM_USER_NAME2} --image ${IMG_USER_ID} --flavor 10 --nic net-id=$(get_netid_by_name "$NET_INT2")

unset OS_TENANT_NAME
unset OS_USERNAME
unset OS_PASSWORD
unset OS_AUTH_URL
echo_g "<<<Done" && exit 0
