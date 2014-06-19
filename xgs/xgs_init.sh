#!/bin/sh
#Follow the steps at https://w3-connections.ibm.com/wikis/home?lang=en-us#!/wiki/Stefan's%20Corner/page/Havana%20--%20XGSPlugin%20Installation%20Instructions%20V1
#https://w3-connections.ibm.com/wikis/home?lang=en-us#!/wiki/Stefan's%20Corner/page/IceHouse%20--%20XGSPlugin%20Installation%20Instructions
#This script will create two nets/subnets and boot an xgs vm

[ ! -e header.sh ] && echo_r "Not found header file" && exit -1
. ./header.sh

## MAIN PROCESSING START ##
echo_b ">>>Starting the IPSaaS initialization..."

echo_b "Checking the xgs image file..."
[ ! -f ${IMG_XGS_FILE} ] && echo_r "vm image ${IMG_XGS_FILE} not found" exit -1;

echo_b "Check the user image file..."
[ ! -f ${IMG_USER_FILE} ] && echo_r "vm image ${IMG_USER_FILE} not found" exit -1; 

echo_b "Checking tenant ${TENANT_NAME}"
create_tenant "$TENANT_NAME" "$TENANT_DESC" && sleep 1
TENANT_ID=$(get_tenantid_by_name "$TENANT_NAME") && echo_g "tenant id = ${TENANT_ID}"

echo_b "Checking user..."
create_user "${USER_NAME}" "${USER_PWD}" "${TENANT_ID}" "${USER_EMAIL}"
sleep 1

echo_b "Creating 4 nets and subnets for the xgs vm"
create_net_subnet "$NET_XGS1" "$SUBNET_XGS1" "10.0.1.0/24" "10.0.1.1"
create_net_subnet "$NET_XGS2" "$SUBNET_XGS2" "10.0.2.0/24" "10.0.2.1"
create_net_subnet "$NET_XGS3" "$SUBNET_XGS3" "10.0.3.0/24" "10.0.3.1"
create_net_subnet "$NET_XGS4" "$SUBNET_XGS4" "10.0.4.0/24" "10.0.4.1"

echo_b "Creating 2 nets and subnets for the user vm"
create_net_subnet "$NET_INT1" "$SUBNET_INT1" "192.168.1.0/24" "192.168.1.1"
create_net_subnet "$NET_INT2" "$SUBNET_INT2" "192.168.2.0/24" "192.168.2.1"

echo_b "Checking the router, add its interface between user subnet..."
create_router "${ROUTER_NAME}" "${TENANT_ID}"
ROUTER_ID=$(get_routerid_by_name "${ROUTER_NAME}")
SUBNET_ID1=$(get_subnetid_by_name "$SUBNET_INT1")
SUBNET_ID2=$(get_subnetid_by_name "$SUBNET_INT2")
if [ -n "${ROUTER_ID}" -a -n "${SUBNET_ID1}" -a -n "${SUBNET_ID2}" ]; then 
    echo "Adding router interface into the user subnets..."
    #neutron router-interface-add ${ROUTER_ID} ${SUBNET_ID1}
    #neutron router-interface-add ${ROUTER_ID} ${SUBNET_ID2}
fi

echo_b "Adding the user_vm, xgs, xgs_inited image file into glance..."
create_image "${IMG_USER_NAME}" "${IMG_USER_FILE}"
create_image "${IMG_XGS_NAME}" "${IMG_XGS_FILE}"
glance image-update --property hw_disk_bus=ide --property hw_vif_model=rtl8139 "${IMG_XGS_NAME}"
#create_image ${IMG_XGS_INITED_NAME} ${IMG_XGS_INITED_FILE}
#glance image-update --property hw_disk_bus=ide --property hw_vif_model=rtl8139 ${IMG_XGS_INITED_NAME}
IMG_XGS_ID=`glance image-list|grep "${IMG_XGS_NAME}"|awk '{print $2}'`
[ -z "${IMG_XGS_ID}" ] && echo_r "image ${IMG_XGS_NAME} is not found in glance" && exit -1
IMG_USER_ID=`glance image-list|grep "${IMG_USER_NAME}"|awk '{print $2}'`
[ -z "${IMG_USER_ID}" ] && echo_r "image "${IMG_USER_NAME}" is not found in glance" && exit -1
IMG_ROUTED_ID=`glance image-list|grep "${IMG_ROUTED_NAME}"|awk '{print $2}'`
[ -z "${IMG_ROUTED_ID}" ] && echo_r "image ${IMG_ROUTED_NAME} is not found in glance" && exit -1

echo_b "Creating new flavors..."
[ -z "`nova flavor-list|grep ex.xgs`" ] && nova flavor-create --is-public true ex.xgs 20 1024 10 1
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

echo_b "Booting the user vms..."
nova boot ${VM_USER_NAME1} --image ${IMG_USER_ID} --flavor 10 --availability-zone az1 \
--nic net-id=$(get_netid_by_name "$NET_INT1")
sleep 1
nova boot ${VM_USER_NAME2} --image ${IMG_USER_ID} --flavor 10 --availability-zone az1 \
--nic net-id=$(get_netid_by_name "$NET_INT2")
sleep 1

echo_b "Booting the routed_mb vm..."
nova boot ${VM_ROUTED_NAME} --image ${IMG_ROUTED_ID} --flavor 1 --availability-zone az1 \
--nic net-id=$(get_netid_by_name "$NET_INT1") \
--nic net-id=$(get_netid_by_name "$NET_INT2")
sleep 1

echo_b "Booting the xgs vm..."
nova boot ${VM_XGS_NAME} --image ${IMG_XGS_ID} --flavor 20 --availability-zone az1 \
--nic net-id=$(get_netid_by_name $NET_XGS1) \
--nic net-id=$(get_netid_by_name $NET_XGS2) \
--nic net-id=$(get_netid_by_name $NET_XGS3) \
--nic net-id=$(get_netid_by_name $NET_XGS4)
sleep 2

unset OS_TENANT_NAME
unset OS_USERNAME
unset OS_PASSWORD
unset OS_AUTH_URL

echo_b "Suggest move xgs's management interfaces to other bridge in the compute node."
echo "10.0.1.2:" $(get_port_by_ip 10.0.1.2)
echo "10.0.2.2:" $(get_port_by_ip 10.0.2.2)

echo_g "<<<Done" && exit 0
