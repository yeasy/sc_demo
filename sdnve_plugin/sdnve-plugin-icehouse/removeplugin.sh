#/bin/bash
# vim: tabstop=4 shiftwidth=4 softtabstop=4
# Copyright 2013 IBM
# All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

# usage() { echo "Usage: $0 -p <OSEE|DEVSTACK>" 1>&2; exit 1; }

# while getopts ":p:" o; do
#     case "${o}" in
#         p)
#             PRODUCT=${OPTARG}
#             ;;
#         *)
#             usage
#             exit 1
#             ;;
#     esac
# done
# shift $((OPTIND-1))

# if [ "${PRODUCT}" != "OSEE" -a "${PRODUCT}" != "DEVSTACK" ]
# then
#     usage
#     exit 1
# fi

#The changes by this scripts (RDO):
#Remove directories:
    #/etc/neutron/ibm/
    #/usr/lib/python2.6/site-packages/neutron/plugins/ibm/
    #/etc/init.d/neutron-sdnve-agent
    #/usr/bin/neutron-sdnve-agent
#Restore files:
    #/etc/nova/nova.conf
    #/etc/neutron/neutron.conf
    #/etc/neutron/plugin.ini

SDNVE_AGENT="plugin-archive/int_support/neutron-sdnve-agent"

RC_DIR=/etc/init.d
PYTHON_PKG_DIR=`python -c "from distutils.sysconfig import get_python_lib; print get_python_lib()"`

get_pid () {
    [ $# -ne 1 ] && return 0
    local NAME=$1
    PID=`ps -aef | grep -E $NAME | grep -v grep | awk '{print $2}'`
    #[ -z "`ps -aef | grep -E $NAME | grep -v grep`" ] && return 0
    echo $PID
}
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

if [ -z ${PYTHON_PKG_DIR} ]; then
    echo_r "Cannot find python path, pls install python first"
    exit 1
fi

echo_g ">>>Checking production..."
if [ -x /opt/stack ]
then
   PRODUCT="DEVSTACK"
else
   if [ -e /etc/yum.repos.d/rdo-release.repo ]
   then
      PRODUCT="RDO"
   else
      PRODUCT="OSEE"
   fi
fi
echo "Production is $PRODUCT"

echo_g ">>>Starting removal for $PRODUCT"

echo_g ">>>Stopping the sdnve neutron plugin services..."
PID=$(get_pid "ibm/sdnve_neutron_plugin.ini")
if [ -n "$PID" ]
then
	for i in $PID
	do
		kill -9 $i
	done
fi

echo_g ">>>Removing the installed plugin files..."
if [ "${PRODUCT}" = "OSEE" -o "${PRODUCT}" = "RDO" ]
then
	PLUGIN_LIB_DIR=${PYTHON_PKG_DIR}/neutron/plugins
	PLUGIN_CFG_DIR=/etc/neutron/plugins
	BIN_DIR=/usr/bin/
else
	PLUGIN_LIB_DIR=/opt/stack/neutron/neutron/plugins
	PLUGIN_CFG_DIR=/etc/neutron/plugins
	BIN_DIR=/opt/stack/neutron/bin
fi
[ -e ${PLUGIN_LIB_DIR}/ibm ] && rm -rf ${PLUGIN_LIB_DIR}/ibm 
[ -e ${PLUGIN_CFG_DIR}/ibm ] && rm -rf ${PLUGIN_CFG_DIR}/ibm 
[ -e ${BIN_DIR}/neutron-sdnve-agent ] && rm -f ${BIN_DIR}/neutron-sdnve-agent 
[ -e ${RC_DIR}/neutron-sdnve-agent ] && rm -f ${RC_DIR}/neutron-sdnve-agent

# Revert back the configuration files
echo_g ">>>Restore configuration files (nova.conf and neutron.conf)..."

echo "Restore nova.conf"
if [ "${PRODUCT}" = "OSEE" -o "${PRODUCT}" = "RDO" ]; then
    [ -e /etc/nova/nova.conf.bak ] && mv -f /etc/nova/nova.conf.bak /etc/nova/nova.conf 2>/dev/null
	chgrp nova /etc/nova/nova.conf
	chmod 640 /etc/nova/nova.conf
fi

echo "Restore neutron.conf"
[ -e /etc/neutron/neutron.conf.bak ] && mv -f /etc/neutron/neutron.conf.bak /etc/neutron/neutron.conf 2>/dev/null
chmod 640 /etc/neutron/neutron.conf
chgrp neutron /etc/neutron/neutron.conf

echo "Link the ovs_neutron_plugin.ini to /etc/neutron/plugin.ini"
if [ "${PRODUCT}" = "OSEE" -o "${PRODUCT}" = "RDO" ]; then
	rm -f /etc/neutron/plugin.ini
	ln -s -f ${PLUGIN_CFG_DIR}/openvswitch/ovs_neutron_plugin.ini /etc/neutron/plugin.ini
    sync
fi

if [ "${PRODUCT}" = "OSEE" -o "${PRODUCT}" = "RDO" ]; then
    #only run on control node
    if [[ $# -eq 1 &&  $1 -eq 1 ]]; then
        echo_g ">>>[Control Node]: Restarting neutron-server and dhcp, l3 agent"
        /etc/init.d/neutron-server restart && sleep 1
        /etc/init.d/neutron-dhcp-agent restart
        /etc/init.d/neutron-l3-agent restart
    fi
    ovs-vsctl del-controller br-int
    echo_g ">>>Restart neutron-openvswitch-agent"
    /etc/init.d/neutron-openvswitch-agent restart

	echo_g ">>>Restarting Nova services"
	NOVA_SERVICES="api conductor compute scheduler"
	for svc in $NOVA_SERVICES; do service openstack-nova-$svc restart; done

	# If removeplugin.sh is not invoked from standard directory, it means that
	# we have to remove the configuration we had made to start at machine boot
	# time and also remove the plugin files from the standard directory
	#if [ "${PWD}" != "/etc/ibm/plugin" ]
	#then
	#	rm -rf /etc/ibm/plugin
	#	sed -i '/removeplugin.sh/d' /etc/rc.d/rc.local
	#	sed -i '/installplugin.sh/d' /etc/rc.d/rc.local
	#fi
	unset OS_TENANT_NAME
	unset OS_USERNAME
	unset OS_PASSWORD
	unset OS_AUTH_URL
fi

if [[ $# -eq 1 && $1 -eq 1 ]]; then
    service neutron-server status
fi
service neutron-openvswitch-agent status
echo_g "Removal Done."
