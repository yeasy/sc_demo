#!/bin/bash
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
#Add directories:
    #/etc/neutron/ibm/
    #/usr/lib/python2.6/site-packages/neutron/plugins/ibm/
    #/etc/init.d/neutron-sdnve-agent
    #/usr/bin/neutron-sdnve-agent
#Update files:
    #/etc/nova/nova.conf
    #/etc/neutron/neutron.conf
    #/etc/neutron/plugin.ini

SDNVE_AGENT="plugin-archive/int_support/neutron-sdnve-agent"
SDNVE_AGENT_RC="plugin-archive/int_support/rc/neutron-sdnve-agent"
SDNVE_PLUGIN_DIR="plugin-latest/ibm"
SDNVE_PLUGIN_INI="plugin-archive/int_support/sdnve_neutron_plugin.ini"

RC_DIR=/etc/init.d
PYTHON_PKG_DIR=`python -c "from distutils.sysconfig import get_python_lib; print get_python_lib()"`
NEUTRON_EXE=`which neutron-server`

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
# FIXME: Find out the reliable way of checking which is the flavor
if [ -x /opt/stack ]; then
   PRODUCT="DEVSTACK"
elif [ -e /etc/yum.repos.d/rdo-release.repo ]; then
    PRODUCT="RDO"
else
    PRODUCT="OSEE"
fi
echo "Production is $PRODUCT"
if [ "${PRODUCT}" = "OSEE" -o "${PRODUCT}" = "RDO" ]
then
	PLUGIN_LIB_DIR=${PYTHON_PKG_DIR}/neutron/plugins
	PLUGIN_CFG_DIR=/etc/neutron/plugins
	BIN_DIR=/usr/bin
else
	PLUGIN_LIB_DIR=/opt/stack/neutron/neutron/plugins
	PLUGIN_CFG_DIR=/etc/neutron/plugins
	BIN_DIR=/opt/stack/neutron/bin
fi

echo_g ">>>Checking installation package..."
[ ! -r plugin-latest/ibm ] && echo_r "Plugin is not present, exiting" && exit 1

echo_g ">>>Checking existing running IBM Plugin/Agent..."
[ -n "$(get_pid ibm/sdnve_neutron_plugin.ini)" ] && echo_r "IBM Plugin/Agent is alreay running, exiting...." && exit 1

echo_g ">>> Checking the possible previous installation"
if [ -r ${PLUGIN_LIB_DIR}/ibm -o -r ${PLUGIN_CFG_DIR}/ibm -o -r ${BIN_DIR}/neutron-sdnve-agent ]
then
    echo_r "IBM Plugin files are existed, Remove them and restart installation first:"
    if [ -r ${PLUGIN_LIB_DIR}/ibm ]; then
        echo "${PLUGIN_LIB_DIR}/ibm"
    elif [ -r ${PLUGIN_CFG_DIR}/ibm ]; then
        echo "${PLUGIN_CFG_DIR}/ibm"
    elif [ -r ${BIN_DIR}/neutron-sdnve-agent ]; then
        echo "${BIN_DIR}/neutron-sdnve-agent"
    fi
	exit 1
fi

echo_g ">>>Starting installation for $PRODUCT"

echo_g ">>>Stopping services..."
echo ">>>Kill the neutron-server"
PLUGIN_PID=$(get_pid neutron-server)
[ -n "$PLUGIN_PID" ] && kill -9 $PLUGIN_PID

echo "Kill the neutron-openvswitch-agent"
AGT_PID=$(get_pid neutron-openvswitch-agent)
[ -n "$AGT_PID" ] && kill -9 $AGT_PID

echo "Kill the neutron-dhcp-agent and neutron-l3-agent"
DHCP_PID=$(get_pid neutron-dhcp-agent)
[ -n "$DHCP_PID" ] && kill -9 $DHCP_PID

echo "Kill the neutron-l3-agent"
L3_PID=$(get_pid neutron-l3-agent)
[ -n "$L3_PID" ] && kill -9 $L3_PID

echo ">>>Copy the Plugin files into system"
cp -a ${SDNVE_PLUGIN_DIR} ${PLUGIN_LIB_DIR}/
cp -a  ${PLUGIN_CFG_DIR}/openvswitch/  ${PLUGIN_CFG_DIR}/ibm
rm ${PLUGIN_CFG_DIR}/ibm/ovs_neutron_plugin.ini && cp ${SDNVE_PLUGIN_INI} ${PLUGIN_CFG_DIR}/ibm
install ${SDNVE_AGENT} ${BIN_DIR}
install ${SDNVE_AGENT_RC} ${RC_DIR}

sleep 1

echo_g ">>>Configuring the IBM Plugin files"
if [ "${PRODUCT}" = "OSEE" -o "${PRODUCT}" = "RDO" ]; then
    echo "Backup /etc/nova/nova.conf"
	[ ! -e /etc/nova/nova.conf.bak ] && cp /etc/nova/nova.conf /etc/nova/nova.conf.bak
    echo "Update /etc/nova/nova.conf to disable security_group_api, linuxnet_interface_driver, change libvirt_vif_driver=nova.virt.libvirt.vif.LibvirtGenericVIFDriver"
    perl -p -i -e 's/^(security_group_api.*)/#\1/' /etc/nova/nova.conf
    perl -p -i -e 's/^(linuxnet_interface_driver\s*=\s*).*/#\1/' /etc/nova/nova.conf
    perl -p -i -e 's/^(libvirt_vif_driver\s*=\s*).*/\1nova.virt.libvirt.vif.LibvirtGenericVIFDriver/' /etc/nova/nova.conf
    chmod 640 /etc/nova/nova.conf
    chgrp nova /etc/nova/nova.conf
fi

echo "Backup /etc/neutron/neutron.conf"
[ ! -e /etc/neutron/neutron.conf.bak ] && cp /etc/neutron/neutron.conf /etc/neutron/neutron.conf.bak

echo "Update the neutron.conf to point to new plugin"
perl -p -i -e 's/^(core_plugin\s*=\s*).*/\1neutron.plugins.ibm.sdnve_neutron_plugin.SdnvePluginV2/' /etc/neutron/neutron.conf
[[ $? -ne 0 ]] && exit 1
chmod 640 /etc/neutron/neutron.conf
chgrp neutron /etc/neutron/neutron.conf

echo "Update sql connection in sdnve_neutron_plugin.ini"
if [ "${PRODUCT}" = "OSEE" -o "${PRODUCT}" = "RDO" ]; then
	DB_CONN=`grep "^connection = " /etc/neutron/neutron.conf`
fi
[ $DB_CONN ] && sed -i "s,^connection.*,$DB_CONN," ${PLUGIN_CFG_DIR}/ibm/sdnve_neutron_plugin.ini

echo "Link the sdnve_neutron_plugin.ini to /etc/neutron/plugin.ini"
if [ "${PRODUCT}" = "OSEE" -o "${PRODUCT}" = "RDO" ]; then
	ln -s -f ${PLUGIN_CFG_DIR}/ibm/sdnve_neutron_plugin.ini /etc/neutron/plugin.ini
	sync
fi
chgrp neutron /etc/neutron/plugins/ibm/sdnve_neutron_plugin.ini
chgrp neutron /etc/neutron/plugin.ini

#if [ "${PRODUCT}" = "OSEE" ]
#then
	#perl -p -i -e 's/^#\s*(debug\s*=\s*)/\1True/' /etc/neutron/neutron.conf
	#perl -p -i -e 's/^#\s*(verbose\s*=\s*)/\1True/' /etc/neutron/neutron.conf  #This may be overrided by defines in sdnve_neutron_plugin.ini 
#fi

#if [ "${PRODUCT}" = "RDO" ]
#then
	#perl -p -i -e 's/(^debug\s*=\s*).*/\1True/' /etc/neutron/neutron.conf
	#perl -p -i -e 's/(^connection\s*=\s*.*)ovs_neutron/\1sdnve_neutron/' /etc/neutron/neutron.conf
#fi

sleep 1

if [[ $# -eq 1 && $1 -eq 1 ]]; then
    echo_g ">>>[Control Node]: Start the neutron-server"
    #python ${NEUTRON_EXE} --config-file /etc/neutron/neutron.conf --config-file ${PLUGIN_CFG_DIR}/ibm/sdnve_neutron_plugin.ini > /tmp/ibm-q-svc.log 2>&1 &
    /etc/init.d/neutron-server restart && sleep 1 
fi

echo_g ">>>Starting IBM Agent"
#python ${BIN_DIR}/neutron-sdnve-agent  --config-file /etc/neutron/neutron.conf --config-file  ${PLUGIN_CFG_DIR}/ibm/sdnve_neutron_plugin.ini >/tmp/ibm-q-agt.log 2>&1 &
/etc/init.d/neutron-sdnve-agent start && sleep 1 
#echo `ps aux|grep neutron-sdnve-agent|grep -v grep`

echo_g ">>>Restart openvswitch"
if [ "${PRODUCT}" = "OSEE" -o "${PRODUCT}" = "RDO" ]
then
	service openvswitch restart
else
	sudo service openvswitch-switch restart
fi

#Clean and restart nova services
if [ "${PRODUCT}" = "OSEE" -o "${PRODUCT}" = "RDO" ]; then
	unset OS_USERNAME
	unset OS_PASSWORD
	unset OS_TENANT_NAME
	unset OS_AUTH_URL

	echo_g ">>>Restarting Nova services"
	NOVA_SERVICES="api conductor compute scheduler"
	for svc in $NOVA_SERVICES; do service openstack-nova-$svc restart; done

	# Not a full sys-v type initialization.  Just a hack to start IBM plugin
	# on machine reboot in case of RDO/OSEE
	# We just copy the whole plugin directory to /etc/ibm/plugin and we invoke
	# removeplugin and installplugin from /etc/rc.d/rc.local so that the
	# plugin starts on machine reboot

	# if $PWD informs that it is not started from /etc/ibm/plugin directory, then
	# basically we are installing the plugin for the first time on this machine,
	# so copy the entire plugin to /etc/ibm/plugin and modify the rc.local file
	# to start the plugin os restart
	#if [ "${PWD}" != "/etc/ibm/plugin" ]
	#then
	#	rm -rf /etc/ibm/plugin
	#	mkdir -p /etc/ibm/plugin && cp -r * /etc/ibm/plugin
	#	echo '[[ -x /etc/ibm/plugin/removeplugin.sh ]] && (cd /etc/ibm/plugin && ./removeplugin.sh)' >> /etc/rc.d/rc.local
	#	echo '[[ -x /etc/ibm/plugin/installplugin.sh ]] && (cd /etc/ibm/plugin && ./installplugin.sh)' >> /etc/rc.d/rc.local
	#fi
fi
service neutron-server status
service neutron-sdnve-agent status
echo_g ">>>Installation Done."
