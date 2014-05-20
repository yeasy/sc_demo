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
echo "Removal of plugin for $PRODUCT"

AGT_PID=`ps -aef | grep -E "ibm/sdnve_neutron_plugin.ini" | grep -v grep | awk '{print $2}'`
if [ -n "$AGT_PID" ]
then
	echo "IBM Plugin running, killing it"
	for i in `ps -aef | grep -E "ibm/sdnve_neutron_plugin.ini" | grep -v grep | awk '{print $2}'`
	do
		kill -9 $i
	done
fi

if [ "${PRODUCT}" = "OSEE" -o "${PRODUCT}" = "RDO" ]
then
	IBM_PLUGIN_FILES1=/usr/lib/python2.6/site-packages/neutron/plugins
	IBM_PLUGIN_FILES2=/etc/neutron/plugins
	IBM_PLUGIN_FILES3=/usr/bin/
else
	IBM_PLUGIN_FILES1=/opt/stack/neutron/neutron/plugins
	IBM_PLUGIN_FILES2=/etc/neutron/plugins
	IBM_PLUGIN_FILES3=/opt/stack/neutron/bin
fi
# Check the files of ibm plugin exists on this machine
if [ -r ${IBM_PLUGIN_FILES1}/ibm -o -r ${IBM_PLUGIN_FILES2}/ibm -o -r ${IBM_PLUGIN_FILES3}/neutron-sdnve-agent ]
then
	echo "IBM Plugin files are installed and removing them"
	rm -rf ${IBM_PLUGIN_FILES1}/ibm ${IBM_PLUGIN_FILES2}/ibm ${IBM_PLUGIN_FILES3}/neutron-sdnve-agent /etc/init.d/neutron-sdnve-agent
fi

# Revert back the configuration files
[ -e /etc/neutron/neutron.conf.bak ] && mv -f /etc/neutron/neutron.conf.bak /etc/neutron/neutron.conf 2>/dev/null

if [ "${PRODUCT}" = "OSEE" -o "${PRODUCT}" = "RDO" ]
then
	rm -f /etc/neutron/plugin.ini
	ln -s -f ${IBM_PLUGIN_FILES2}/openvswitch/ovs_neutron_plugin.ini /etc/neutron/plugin.ini
	[ -e /etc/nova/nova.conf.bak ] && mv -f /etc/nova/nova.conf.bak /etc/nova/nova.conf 2>/dev/null
	chmod 640 /etc/nova/nova.conf /etc/neutron/neutron.conf
	chgrp nova /etc/nova/nova.conf
	chgrp neutron /etc/neutron/neutron.conf

	# If removeplugin.sh is not invoked from standard directory, it means that
	# we have to remove the configuration we had made to start at machine boot
	# time and also remove the plugin files from the standard directory
	if [ "${PWD}" != "/etc/ibm/plugin" ]
	then
		rm -rf /etc/ibm/plugin
		sed -i '/removeplugin.sh/d' /etc/rc.d/rc.local
		sed -i '/installplugin.sh/d' /etc/rc.d/rc.local
	fi

    #only run on control node
    if [[ $# -eq 1 &&  $1 -eq 1 ]]; then
        echo "Control node: restart neutron-server and dhcp, l3 agent"
        /etc/init.d/neutron-server restart
        /etc/init.d/neutron-dhcp-agent restart
        /etc/init.d/neutron-l3-agent restart
    fi
    echo "Restart neutron-openvswitch-agent"
    /etc/init.d/neutron-openvswitch-agent restart
fi

echo "Please remove the python lib for neutron plugin manually."
