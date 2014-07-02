


import abc

import netaddr
from oslo.config import cfg
import six

from neutron.agent.common import config
from neutron.agent.linux import ip_lib
from neutron.agent.linux import ovs_lib
from neutron.agent.linux import utils
from neutron.agent.linux import interface
from neutron.common import exceptions
from neutron.extensions.flavor import (FLAVOR_NETWORK)
from neutron.openstack.common import importutils
from neutron.openstack.common import log as logging


LOG = logging.getLogger(__name__)


class SdnveDhcpBridgeInterfaceDriver(interface.LinuxInterfaceDriver):
    """Driver for creating dhcp ports in Sdnve."""

    DEV_NAME_PREFIX = 'ns-'

    def plug(self, network_id, port_id, device_name, mac_address,
             bridge=None, namespace=None, prefix=None):
        """Plugin the interface."""
        if not ip_lib.device_exists(device_name,
                                    self.root_helper,
                                    namespace=namespace):
            ip = ip_lib.IPWrapper(self.root_helper)

            # Enable agent to define the prefix
            if prefix:
                tap_name = device_name.replace(prefix, 'tap')
            else:
                tap_name = device_name.replace(self.DEV_NAME_PREFIX, 'tap')
            # Create ns_veth in a namespace if one is configured.
            root_veth, ns_veth = ip.add_veth(tap_name, device_name,
                                             namespace2=namespace)
            ns_veth.link.set_address(mac_address)

            if self.conf.network_device_mtu:
                root_veth.link.set_mtu(self.conf.network_device_mtu)
                ns_veth.link.set_mtu(self.conf.network_device_mtu)

            root_veth.link.set_up()
            ns_veth.link.set_up()

            bridge_name = 'brq'+network_id[0:11]
            LOG.info(_("register neutron dhcp port, pUUID=%s,nwUUID=%s,bridge=%s,tap=%s,peer=%s"%(port_id,network_id,bridge_name,tap_name,device_name)))

            cmd = ['dactl','register', 'neutrondhcpport', port_id, network_id, bridge_name, tap_name, device_name]
            utils.execute(cmd, self.root_helper)

            # create the iptables mangle rule in the namespace
            if namespace == None:
                #delete and readd the iptables global rule
                cmd = ["iptables", "-t", "mangle", "-D", "POSTROUTING", "-p", "udp","--dport", "bootpc", "-j", "CHECKSUM", "--checksum-fill"]
                utils.execute(cmd, self.root_helper)         
                cmd = ["iptables", "-t", "mangle", "-A", "POSTROUTING", "-p", "udp","--dport", "bootpc", "-j", "CHECKSUM", "--checksum-fill"]
                utils.execute(cmd, self.root_helper)         
            else:
                # 
                cmd = ['ip','netns', 'exec', "%s"%namespace, "iptables", "-t", "mangle", "-A", "POSTROUTING", "-p", "udp","--dport", "bootpc", "-j", "CHECKSUM", "--checksum-fill"]
                utils.execute(cmd, self.root_helper)         
            
        else:
            LOG.info(_("Device %s already exists"), device_name)

    def unplug(self, device_name, bridge=None, namespace=None, prefix=None):
        """Unplug the interface."""
        device = ip_lib.IPDevice(device_name, self.root_helper, namespace)
        try:
            LOG.info(_("unregister neutron dhcp port, devicename=%s"%device_name))
            cmd = ['dactl','unregister', 'neutrondhcpport', device_name]
            utils.execute(cmd, self.root_helper)
            device.link.delete()
            LOG.debug(_("Unplugged interface '%s'"), device_name)
            # clean up
            #if namespace:
            #    ip = ip_lib.IPWrapper(self.root_helper,namespace)
            #    LOG.info(_("cleanup namespace=%s"%namespace))            
            #    ip.garbage_collect_namespace()
            
        except RuntimeError:
            LOG.error(_("Failed unplugging interface '%s'"),
                      device_name)
