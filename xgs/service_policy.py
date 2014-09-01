#This file should be put into the plugin_dirs of OpenStack HEAT.
#plugin_dirs=/usr/lib64/heat,/usr/lib/heat
#After that, restart the heat engine to enable it.
# service openstack-heat-engine restart

#Provide the OS::Neutron::ServicePolicy resource.

from heat.engine import attributes
from heat.engine import properties
from heat.engine import resource
from heat.openstack.common import log as logging

LOG = logging.getLogger(__name__)


class ServicePolicy(resource.Resource):

    PROPERTIES = (
        NAME, SRC, DST,
    ) = (
        'name', 'src', 'dst',
    )

    ATTRIBUTES = (
        NAME,
    )

    properties_schema = {
        NAME: properties.Schema(
            properties.Schema.STRING,
            _('Name of the service policy.')
        ),
        SRC: properties.Schema(
            properties.Schema.STRING,
            _('Source of the service policy.')
        ),
        DST: properties.Schema(
            properties.Schema.STRING,
            _('Destination of the service policy.')
        ),
    }
    attributes_schema = {
        NAME: attributes.Schema(
            _('Name of the service policy.')
        ),
    }

    def handle_create(self):
        print self.properties.get(self.NAME)
        print self.properties.get(self.SRC)
        print self.properties.get(self.DST)
        pass

    def handle_delete(self):
        pass

    def _resolve_attribute(self, name):
        if name == self.NAME:
            return self.properties.get(self.NAME)

def resource_mapping():
    return {
        'OS::Neutron::ServicePolicy': ServicePolicy,
    }
