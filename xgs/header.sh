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

IMG_XGS_NAME="trans_mb"
IMG_XGS_FILE=ISNP_5.2_20140502-1219_personal_compat.qcow2
IMG_XGS_INITED_NAME="ISNP_XGS_INITED"
IMG_XGS_INITED_FILE=ISNP_5.2_20140502-1219_personal_compat_inited.qcow2
VM_XGS_NAME="trans_mb"

NET_XGS1="net_xgs_manage1"
NET_XGS2="net_xgs_manage2"
NET_XGS3="net_xgs_data1"
NET_XGS4="net_xgs_data2"
SUBNET_XGS1="subnet_xgs_manage1"
SUBNET_XGS2="subnet_xgs_manage2"
SUBNET_XGS3="subnet_xgs_data1"
SUBNET_XGS4="subnet_xgs_data2"

NET_INT1="net_int1"
NET_INT2="net_int2"
SUBNET_INT1="subnet_int1"
SUBNET_INT2="subnet_int2"

ROUTER_NAME="router"

IMG_USER_FILE=ubuntu-pc.img
#IMG_USER_URL=https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img
#if not existed will download from ${IMG_USER_URL}
IMG_USER_NAME1="user_vm1"
IMG_USER_NAME2="user_vm2"
VM_USER_NAME1="user_vm1"
VM_USER_NAME2="user_vm2"

IMG_ROUTED_NAME="routed_mb"
VM_ROUTED_NAME="routed_mb"


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

#tenant_name
get_tenantid_by_name () {
    [ $# -ne 1 ] && echo_r "Wrong parameter number is given: $#" && return 0
    local NAME=$1
    [ -z "`keystone tenant-list|grep \"${NAME}\"`" ] && return 0
    echo `keystone tenant-list|grep "${NAME}"|awk '{print $2}'`
}

#net_name
get_netid_by_name () {
    [ $# -ne 1 ] && echo_r "Wrong parameter number is given: $#" && return 0
    local NAME=$1
    [ -z "`neutron net-list|grep \"${NAME}\"`" ] && return 0
    echo `neutron net-list|grep "${NAME}"|awk '{print $2}'`
}

#IP
get_portid_by_ip () {
    [ $# -ne 1 ] && echo_r "Wrong parameter number is given: $#" && return 0
    local IP=$1
    [ -z "`neutron port-list|grep \"${IP}\"`" ] && return 0
    echo `neutron port-list|grep "${IP}"|awk '{print $2}'`
}

#IP
get_port_by_ip () {
    [ $# -ne 1 ] && echo_r "Wrong parameter number is given: $#" && return 0
    local IP=$1
    port_id=$(get_portid_by_ip $IP)
    [ -z "$port_id" ] && return 0
    echo 'tap'${port_id:0:11}
}

#subnet_name
get_subnetid_by_name () {
    [ $# -ne 1 ] && echo_r "Wrong parameter number is given: $#" && return 0
    local NAME=$1
    [ -z "`neutron subnet-list|grep \"${NAME}\"`" ] && return 0
    echo `neutron subnet-list|grep "${NAME}"|awk '{print $2}'`
}

#router_name
get_routerid_by_name () {
    [ $# -ne 1 ] && return 0
    local NAME=$1
    [ -z "`neutron router-list|grep \"${NAME}\"`" ] && return 0
    echo `neutron router-list|grep "${NAME}"|awk '{print $2}'`
}

#net_name, subnet_name, ip_cidr, gateway,
create_net_subnet () {
    [ $# -ne 4 ] && echo_r "Wrong parameter number is given: $#" && exit -1
    local NET_NAME=$1
    local SUBNET_NAME=$2
    local IP_CIDR=$3
    local GATEWAY=$4
    [ -z "`neutron net-list|grep \"${NET_NAME}\"`" ] && neutron net-create --tenant-id ${TENANT_ID} "${NET_NAME}" && sleep 1;
    [ -z "`neutron subnet-list|grep \"${SUBNET_NAME}\"`" ] && neutron subnet-create --tenant-id ${TENANT_ID} --name ${SUBNET_NAME} "${NET_NAME}" ${IP_CIDR} --gateway ${GATEWAY} --dns_nameservers list=true 8.8.8.7 8.8.8.8
}

#net_name, subnet_name
delete_net_subnet () {
    [ $# -ne 2 ] && echo "Wrong parameter number is given: $#" && exit -1
    local NET_NAME=$1
    local SUBNET_NAME=$2
    [ -n "`neutron subnet-list|grep \"${SUBNET_NAME}\"`" ] && neutron subnet-delete $(get_subnetid_by_name "${SUBNET_NAME}")
    [ -n "`neutron net-list|grep \"${NET_NAME}\"`" ] && neutron net-delete $(get_netid_by_name "${NET_NAME}")
}

#tenant_name tenant_desc
create_tenant () {
    [ $# -ne 2 ] && echo_r "Wrong parameter number is given: $#" && exit -1
    local NAME=$1
    local DESC=$2
    [ -z "`keystone tenant-list|grep \"${TENANT_NAME}\"`" ] && keystone tenant-create --name "${NAME}" --description "${DESC}" 
    [ -z "`keystone tenant-list|grep \"${TENANT_NAME}\"`" ] && echo_r "Create tenant $NAME Failed" && exit -1 
}

#user_name user_pwd tenant_id user_email
create_user () {
    [ $# -ne 4 ] && echo_r "Wrong parameter number is given: $#" && exit -1
    local NAME=$1
    local PWD=$2
    local TEN_ID=$3
    local EMAIL=$4
    [ -z "`keystone user-list|grep \"${NAME}\"`" ] && keystone user-create --name "${NAME}" --pass ${PWD} --tenant-id ${TEN_ID} --email ${EMAIL}
    [ -z "`keystone user-list|grep \"${NAME}\"`" ] && echo_r "User creation failed" && exit -1
    local USER_ID=`keystone user-list|grep "${NAME}"|awk '{print $2}'`
    if [ -n "`keystone role-list|grep \"${USER_ROLE}\"`" ]; then
        ROLE_ID=`keystone role-list|grep "${USER_ROLE}"|awk '{print $2}'`
    elif [ -n "`keystone role-list|grep \"${USER_ROLE2}\"`" ]; then
        ROLE_ID=`keystone role-list|grep "${USER_ROLE2}"|awk '{print $2}'`
    else
        echo_r "No role is found"
        exit -1;
    fi
    [ -z "`keystone user-role-list --tenant-id ${TEN_ID} --user-id ${USER_ID}|grep ${ROLE_ID}`" ] && keystone user-role-add --tenant-id ${TEN_ID} --user-id ${USER_ID} --role-id ${ROLE_ID}
    echo_g "User id = $USER_ID"
}
#router_name tenant_id
create_router () {
    [ $# -ne 2 ] && echo_r "Wrong parameter number is given: $#" && exit -1
    local NAME=$1
    local TEN_ID=$2
    [ -z "`neutron router-list|grep \"${NAME}\"`" ] && neutron router-create --tenant-id ${TEN_ID} "${NAME}"
    [ -z "`neutron router-list|grep \"${NAME}\"`" ] && echo_r "Create router "$NAME" Failed" && exit -1 
}

#image_name image_file
create_image () {
    [ $# -ne 2 ] && echo_r "Wrong parameter number is given: $#" && exit -1
    local NAME=$1
    local FILE=$2
    if [ -f ${FILE} -a -z "`glance image-list|grep \"${NAME}\"`" ]; then
        echo "Creating glance image ${NAME}"
        glance image-create --disk-format qcow2 --container-format bare --name "${NAME}" --is-public True --file "${FILE}" --progress
        sleep 1
    fi
}

#image_name
delete_image () {
    [ $# -ne 1 ] && echo "Wrong parameter number is given: $#" && exit -1
    local NAME=$1
    if [ -n "`nova image-list|grep \"${NAME}\"`" ]; then
        local ID=`nova image-list|grep "${NAME}"|awk '{print $2}'`
        glance -f image-delete ${ID}
        sleep 1;
    fi
}

#image_name
get_imageid_by_name () {
    [ $# -ne 1 ] && return 0
    local NAME=$1
    [ -z "`glance image-list|grep \"${NAME}\"`" ] && return 0
    echo `glance image-list|grep "${NAME}"|awk '{print $2}'`
}

#vm_name
delete_vm () {
    [ $# -ne 1 ] && echo "Wrong parameter number is given: $#" && exit -1
    local NAME=$1
    if [ -n "`nova list|grep \"${NAME}\"`" ]; then
        local ID=`nova list|grep "${NAME}"|awk '{print $2}'`
        echo_g "Deleting the vm $NAME..."
        nova delete ${ID}
        sleep 1;
    fi
}

#user_name
delete_user () {
    [ $# -ne 1 ] && echo "Wrong parameter number is given" && exit -1
    local NAME=$1
    if [ -n "`keystone user-list|grep \"${NAME}\"`" ]; then 
        ID=`keystone user-list|grep "${NAME}"|awk '{print $2}'`
        keystone user-delete ${ID}
    fi
}
#tenant_name
delete_tenant () {
    [ $# -ne 1 ] && echo "Wrong parameter number is given" && exit -1
    local NAME=$1
    if [ -n "`keystone tenant-list|grep \"${NAME}\"`" ]; then 
        ID=`keystone tenant-list|grep "${NAME}"|awk '{print $2}'`
        keystone tenant-delete ${ID}
    fi
}
