#The header file that will be included by other scripts.
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
SUBNET_XGS3="xgs_data_subnet1"
SUBNET_XGS4="xgs_data_subnet2"

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

#net_name, subnet_name
delete_net_subnet () {
    [ $# -ne 2 ] && echo "Wrong parameter number is given" && exit -1
    local NET_NAME=$1
    local SUBNET_NAME=$2
    [ -n "`neutron subnet-list|grep ${SUBNET_NAME}`" ] && neutron subnet-delete $(get_subnetid_by_name ${SUBNET_NAME})
    [ -n "`neutron net-list|grep ${NET_NAME}`" ] && neutron net-delete $(get_netid_by_name ${NET_NAME})
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