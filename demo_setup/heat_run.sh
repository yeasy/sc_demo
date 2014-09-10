#!/bin/sh

#This script will create the xgs demo by heat.
#Since currently heat cannot create resources such as tenant, user and flavor, 
#we require some prerequesited scripts to help init the enviroment

[ ! -e header.sh ] && echo_r "Not found header file" && exit -1
. ./header.sh

#Check prerequsite
[ -z `which heatgen 2>/dev/null` ] && echo "Please install heatgen first" &&
exit
[ -z `which br-mv-port 2>/dev/null` ] && cp ./br-mv-port /usr/local/bin/ &&
chmod a+x /usr/local/bin/br-mv-port

echo_b ">>>Starting the IPSaaS initialization..."

echo_b ">>Checking tenant ${TENANT_NAME}"
create_tenant "$TENANT_NAME" "$TENANT_DESC"
TENANT_ID=$(get_tenantid_by_name "$TENANT_NAME") && echo_g "tenant id = ${TENANT_ID}"

echo_b ">>Checking user..."
create_user "${USER_NAME}" "${USER_PWD}" "${TENANT_ID}" "${USER_EMAIL}"

echo_b ">>Checking the user_vm, xgs, xgs_inited image file in Glance..."
create_image "${IMG_USER_NAME1}" "${IMG_USER_FILE}"
create_image "${IMG_USER_NAME2}" "${IMG_USER_FILE}"
[ -z "`glance image-list|grep \"${IMG_XGS_NAME}\"`" ] && create_image "${IMG_XGS_NAME}" "${IMG_XGS_FILE}" && \
glance image-update --property hw_disk_bus=ide --property hw_vif_model=rtl8139 "${IMG_XGS_NAME}"
#create_image ${IMG_XGS_INITED_NAME} ${IMG_XGS_INITED_FILE}
#glance image-update --property hw_disk_bus=ide --property hw_vif_model=rtl8139 ${IMG_XGS_INITED_NAME}
IMG_USER_ID1=`glance image-list|grep "${IMG_USER_NAME1}"|awk '{print $2}'`
[ -z "${IMG_USER_ID1}" ] && echo_r "image "${IMG_USER_NAME1}" is not found in glance" && exit -1
IMG_USER_ID2=`glance image-list|grep "${IMG_USER_NAME2}"|awk '{print $2}'`
[ -z "${IMG_USER_ID2}" ] && echo_r "image "${IMG_USER_NAME2}" is not found in glance" && exit -1
IMG_XGS_ID=`glance image-list|grep "${IMG_XGS_NAME}"|awk '{print $2}'`
[ -z "${IMG_XGS_ID}" ] && echo_r "image ${IMG_XGS_NAME} is not found in glance" && exit -1
IMG_ROUTED_ID=`glance image-list|grep "${IMG_ROUTED_NAME}"|awk '{print $2}'`
[ -z "${IMG_ROUTED_ID}" ] && echo_r "image ${IMG_ROUTED_NAME} is not found in glance" && exit -1

echo_b ">>Checking flavors..."
#[ -z "`nova flavor-list|grep ex.small`" ] && nova flavor-create --is-public true ex.small 11 512 20 1
[ -z "`nova flavor-list|grep ex.tiny`" ] && nova flavor-create --is-public true ex.tiny 10 512 2 1
[ -z "`nova flavor-list|grep ex.xgs`" ] && nova flavor-create --is-public true ex.xgs 20 1024 10 1

#change to user and add security rules
export OS_TENANT_NAME=${TENANT_NAME}
export OS_USERNAME=${USER_NAME}
export OS_PASSWORD=${USER_PWD}

#echo_b "Add default secgroup rules of allowing ping and ssh..."
#nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
#nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
#nova secgroup-add-rule default tcp 80 80 0.0.0.0/0
#nova secgroup-add-rule default tcp 443 443 0.0.0.0/0

function xgs_setup {
	STACK="xgs_stack"
	echo_b ">>Starting the stack $STACK at az1 using Heat..."
	PARAMS="user_image_1=${IMG_USER_ID1};user_image_2=${IMG_USER_ID2};xgs_image=${IMG_XGS_ID};routed_image=${IMG_ROUTED_ID};user_flavor=ex.tiny"
	if [ -n "`heat stack-list|grep \"${STACK}\"`" ]; then
		echo_g "Update existing stack ${STACK}"
		heat stack-update $STACK -f ./xgs_setup.yaml --parameters="${PARAMS}"
	else
		echo_g "Create stack ${STACK}"
		heat stack-create $STACK -f ./xgs_setup.yaml --parameters="${PARAMS}"
	fi
}

function policy_setup {
	STACK="policy_stack"
	dst_file=/usr/lib/heat/service_policy.py
	echo_b ">>Starting the stack $STACK using Heat..."
	[ -d /usr/lib/heat ] || mkdir /usr/lib/heat

	echo_g ">>Check if the ServicePolicy resource exists in system"
	if [ ! -f ${dst_file} ] || ! cmp -s service_policy.py ${dst_file};  then
		echo_g ">>Update the service_policy resource"
		cp ./service_policy.py /usr/lib/heat/
		service openstack-heat-engine restart
		sleep 1
	fi

	PARAMS="src=net_int1;dst=net_int2;services=[trans_mb,routed_mb]"
	if [ -n "`heat stack-list|grep \"${STACK}\"`" ]; then
		echo_g ">>Update existing stack ${STACK}"
		heat stack-update $STACK -e env.yaml -P="${PARAMS}" -f ./policy_setup
		.yaml
	else
		echo_g ">>Create stack ${STACK}"
		heat stack-create $STACK -e env.yaml -P="${PARAMS}" -f ./policy_setup.yaml
	fi
}

#xgs_setup
policy_setup

unset OS_TENANT_NAME
unset OS_USERNAME
unset OS_PASSWORD
unset OS_AUTH_URL

exit

echo_b "Suggest move xgs's management interfaces in the compute node: br-mv-port br-eth0 tapxxx."
echo "10.0.1.2:" $(get_port_by_ip 10.0.1.2)
echo "10.0.2.2:" $(get_port_by_ip 10.0.2.2)


echo_g "<<<Done" && exit 0
