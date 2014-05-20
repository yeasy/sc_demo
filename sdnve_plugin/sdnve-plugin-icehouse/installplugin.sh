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

SDNVE_NEUTRON_AGENT="plugin-archive/int_support/neutron-sdnve-agent"
SDNVE_NEUTRON_AGENT_RC="plugin-archive/int_support/rc/neutron-sdnve-agent"
SDNVE_NEUTRON_PLUGIN_INI="plugin-archive/int_support/sdnve_neutron_plugin.ini"

# FIXME: Find out the reliable way of checking which is the flavor
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
echo "Installation for $PRODUCT"

# Check if plugin directory is present or not
if [ -r havana/ibm ]
then
	echo "Plugin files present in current dir, going ahead with install"
else
	echo "Plugin is not present, exiting"
	exit 1
fi

# Check if ibm plugin and agent are already running
AGT_PID=`ps -aef | grep -E "ibm/sdnve_neutron_plugin.ini" | grep -v grep | awk '{print $2}'`
if [ -n "$AGT_PID" ]
then
	echo "IBM Plugin/Agent is alreay running, exiting...."
	exit 1
fi

if [ "${PRODUCT}" = "OSEE" -o "${PRODUCT}" = "RDO" ]
then
	IBM_PLUGIN_FILES1=/usr/lib/python2.6/site-packages/neutron/plugins
	IBM_PLUGIN_FILES2=/etc/neutron/plugins
	IBM_PLUGIN_FILES3=/usr/bin
else
	IBM_PLUGIN_FILES1=/opt/stack/neutron/neutron/plugins
	IBM_PLUGIN_FILES2=/etc/neutron/plugins
	IBM_PLUGIN_FILES3=/opt/stack/neutron/bin
fi
# Check the files of ibm plugin exists on this machine
if [ -r ${IBM_PLUGIN_FILES1}/ibm -o -r ${IBM_PLUGIN_FILES2}/ibm -o -r ${IBM_PLUGIN_FILES3}/neutron-sdnve-agent ]
then
    echo "IBM Plugin files are existed, Remove them and restart installation first:"
    if [ -r ${IBM_PLUGIN_FILES1}/ibm ]; then
        echo "${IBM_PLUGIN_FILES1}/ibm"
    fi
    if [ -r ${IBM_PLUGIN_FILES2}/ibm ]; then
        echo "${IBM_PLUGIN_FILES2}/ibm"
    fi
    if [ -r ${IBM_PLUGIN_FILES3}/neutron-sdnve-agent ]; then
        echo "${IBM_PLUGIN_FILES3}/neutron-sdnve-agent"
    fi
	exit 1
fi

# Kill the ovs-network-plugin, ovs-agent, dhcp and l3

AGT_PID=`ps -aef | grep neutron-openvswitch-agent | grep -v grep | awk '{print $2}'`
if [ -n "$AGT_PID" ]
then
	echo "Killing openswitch agent"
	kill -9 $AGT_PID
fi

PLUGIN_PID=`ps -aef | grep neutron-server | grep -v grep | awk '{print $2}'`
if [ -n "$PLUGIN_PID" ]
then
	echo "Killing openswitch plugin"
	kill -9 $PLUGIN_PID
fi

DHCP_PID=`ps -aef | grep neutron-dhcp-agent | grep -v grep | awk '{print $2}'`
if [ -n "$DHCP_PID" ]
then
	echo "Killing openswitch dhcp agent"
	kill -9 $DHCP_PID
fi

L3_PID=`ps -aef | grep neutron-l3-agent | grep -v grep | awk '{print $2}'`
if [ -n "$L3_PID" ]
then
	echo "Killing openswitch l3 agent"
	kill -9 $L3_PID
fi

echo "Installing the IBM Plugin files"
# Copy the required files for this plugin
cp -a havana/ibm ${IBM_PLUGIN_FILES1}/.
cp -a  ${IBM_PLUGIN_FILES2}/openvswitch/  ${IBM_PLUGIN_FILES2}/ibm
cp ${SDNVE_NEUTRON_AGENT} ${IBM_PLUGIN_FILES3}
chmod a+x ${IBM_PLUGIN_FILES3}/neutron-sdnve-agent
cp ${SDNVE_NEUTRON_AGENT_RC} /etc/init.d/
chmod a+x /etc/init.d/neutron-sdnve-agent

# Rename the ovs plugin file and copy our ini file over there
rm ${IBM_PLUGIN_FILES2}/ibm/ovs_neutron_plugin.ini && cp ${SDNVE_NEUTRON_PLUGIN_INI} ${IBM_PLUGIN_FILES2}/ibm

sleep 1
echo "Configuring the IBM Plugin files"
# Backup /etc/neutron/neutron.conf
if [ ! -e /etc/neutron/neutron.conf.bak ]
then
	cp /etc/neutron/neutron.conf /etc/neutron/neutron.conf.bak
fi
# Change the neutron configuration to point to our plugin
perl -p -i -e 's/^(core_plugin\s*=\s*).*/\1neutron.plugins.ibm.sdnve_neutron_plugin.SdnvePluginV2/' /etc/neutron/neutron.conf
[[ $? -ne 0 ]] && exit 1

# Backup /etc/nova/nova.conf
if [ "${PRODUCT}" = "OSEE" -o "${PRODUCT}" = "RDO" ]
then
	if [ ! -e /etc/nova/nova.conf.bak ]
	then
		cp /etc/nova/nova.conf /etc/nova/nova.conf.bak
	fi
fi

# Try to get the sql connection string from ovs configuration file and use the same over here
if [ "${PRODUCT}" = "OSEE" -o "${PRODUCT}" = "RDO" ]
then
	DB_CONN=`grep ^sql_connection ${IBM_PLUGIN_FILES2}/openvswitch/ovs_neutron_plugin.ini`
else
	DB_CONN=`grep ^connection ${IBM_PLUGIN_FILES2}/openvswitch/ovs_neutron_plugin.ini`
fi
[ $DB_CONN ] && sed -i "s,^connection.*,$DB_CONN," ${IBM_PLUGIN_FILES2}/ibm/sdnve_neutron_plugin.ini

# After copying the files, we are forcefully linking our plugin
if [ "${PRODUCT}" = "OSEE" -o "${PRODUCT}" = "RDO" ]
then
	ln -s -f ${IBM_PLUGIN_FILES2}/ibm/sdnve_neutron_plugin.ini /etc/neutron/plugin.ini
	sync
	sed -i 's,/usr/local/bin/neutron-rootwrap,/usr/bin/neutron-rootwrap,' ${IBM_PLUGIN_FILES2}/ibm/sdnve_neutron_plugin.ini
fi

if [ "${PRODUCT}" = "OSEE" ]
then
	#perl -p -i -e 's/^#\s*(debug\s*=\s*)/\1True/' /etc/neutron/neutron.conf
	perl -p -i -e 's/^#\s*(verbose\s*=\s*)/\1True/' /etc/neutron/neutron.conf  #This may be overrided by defines in sdnve_neutron_plugin.ini 
fi

if [ "${PRODUCT}" = "RDO" ]
then
	#perl -p -i -e 's/(^debug\s*=\s*).*/\1True/' /etc/neutron/neutron.conf
	perl -p -i -e 's/(^connection\s*=\s*.*)ovs_neutron/\1sdnve_neutron/' /etc/neutron/neutron.conf
fi

sleep 1
if [ "${PRODUCT}" = "OSEE" -o "${PRODUCT}" = "RDO" ]
then
	NEUTRON_EXE=/usr/bin/neutron-server
else
	NEUTRON_EXE=/usr/local/bin/neutron-server
fi

# Start the plugin at control node
if [[ $# -eq 1 && $1 -eq 1 ]]; then
    echo "Control node: Starting IBM Plugin"
    #python ${NEUTRON_EXE} --config-file /etc/neutron/neutron.conf --config-file ${IBM_PLUGIN_FILES2}/ibm/sdnve_neutron_plugin.ini > /tmp/ibm-q-svc.log 2>&1 &
    /etc/init.d/neutron-server restart
    sleep 1 
    #echo `ps aux|grep ${NEUTRON_EXE}|grep -v grep`
fi

echo "Starting IBM Agent"
#python ${IBM_PLUGIN_FILES3}/neutron-sdnve-agent  --config-file /etc/neutron/neutron.conf --config-file  ${IBM_PLUGIN_FILES2}/ibm/sdnve_neutron_plugin.ini >/tmp/ibm-q-agt.log 2>&1 &
/etc/init.d/neutron-sdnve-agent start
sleep 1 
#echo `ps aux|grep neutron-sdnve-agent|grep -v grep`

# Restart openvswitch to inform the controller that it is a new switch

if [ "${PRODUCT}" = "OSEE" -o "${PRODUCT}" = "RDO" ]
then
	service openvswitch restart
else
	sudo service openvswitch-switch restart
fi

#Clean and restart nova services
if [ "${PRODUCT}" = "OSEE" -o "${PRODUCT}" = "RDO" ]
then
	unset OS_USERNAME
	unset OS_PASSWORD
	unset OS_TENANT_NAME
	unset OS_AUTH_URL
	# since we modified nova.conf we need to restart some services so nova uses neutron
	# note: we don't restart all nova services intentionally - not all are needed
	#grep -e security_group_api -e libvirt_vif_driver -e linuxnet_interface_driver /etc/nova/nova.conf
	perl -p -i -e 's/^(security_group_api.*)/#\1/' /etc/nova/nova.conf
	perl -p -i -e 's/^(libvirt_vif_driver\s*=\s*).*/\1nova.virt.libvirt.vif.LibvirtGenericVIFDriver/' /etc/nova/nova.conf
	perl -p -i -e 's/^(linuxnet_interface_driver\s*=\s*).*/#\1/' /etc/nova/nova.conf

	# Change the permissions of the file we touched appropriately.
	chmod 640 /etc/nova/nova.conf /etc/neutron/neutron.conf
	chgrp nova /etc/nova/nova.conf
	chgrp neutron /etc/neutron/neutron.conf
    chgrp neutron /etc/neutron/plugins/ibm/sdnve_neutron_plugin.ini
    chgrp neutron /etc/neutron/plugin.ini
	#grep -e security_group_api -e libvirt_vif_driver -e linuxnet_interface_driver /etc/nova/nova.conf
	echo "Restarting Nova services to use Neutron configuration..."
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
	if [ "${PWD}" != "/etc/ibm/plugin" ]
	then
		rm -rf /etc/ibm/plugin
		mkdir -p /etc/ibm/plugin && cp -r * /etc/ibm/plugin
		echo '[[ -x /etc/ibm/plugin/removeplugin.sh ]] && (cd /etc/ibm/plugin && ./removeplugin.sh)' >> /etc/rc.d/rc.local
		echo '[[ -x /etc/ibm/plugin/installplugin.sh ]] && (cd /etc/ibm/plugin && ./installplugin.sh)' >> /etc/rc.d/rc.local
	fi
fi
