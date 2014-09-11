#This file should be put into the plugin_dirs of OpenStack HEAT.
#plugin_dirs=/usr/lib64/heat,/usr/lib/heat
#After that, restart the heat engine to enable it.
# service openstack-heat-engine restart

#Provide the OS::Neutron::ServicePolicy resource.

import subprocess,os,shlex,signal

from eventlet import greenthread

from subprocess import Popen, PIPE

from heat.engine import attributes
from heat.engine import properties
from heat.engine import resource
from heat.openstack.common import log as logging

LOG = logging.getLogger(__name__)

TMP_CONF = '/tmp/temp_config.conf'

def _subprocess_setup():
    # Python installs a SIGPIPE handler by default. This is usually not what
    # non-Python subprocesses expect.
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)

def subprocess_popen(args, stdin=None, stdout=None, stderr=None, shell=False,
                     env=None):
    return subprocess.Popen(args, shell=shell, stdin=stdin, stdout=stdout,
                            stderr=stderr, preexec_fn=_subprocess_setup,
                            close_fds=True, env=env)

def create_process(cmd, root_helper=None, addl_env=None):
    """Create a process object for the given command.

    The return value will be a tuple of the process object and the
    list of command arguments used to create it.
    """
    if root_helper:
        cmd = shlex.split(root_helper) + cmd
    cmd = map(str, cmd)

    env = os.environ.copy()
    if addl_env:
        env.update(addl_env)

    obj = subprocess_popen(cmd, shell=False,
                                 stdin=subprocess.PIPE,
                                 stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE,
                                 env=env)

    return obj, cmd


def execute(cmd, root_helper=None, process_input=None, addl_env=None,
            check_exit_code=True, return_stderr=False, log_fail_as_error=True):
    try:
        obj, cmd = create_process(cmd, root_helper=root_helper,
                                  addl_env=addl_env)
        _stdout, _stderr = (process_input and
                            obj.communicate(process_input) or
                            obj.communicate())
        obj.stdin.close()
        m = _("\nCommand: %(cmd)s\nExit code: %(code)s\nStdout: %(stdout)r\n"
              "Stderr: %(stderr)r") % {'cmd': cmd, 'code': obj.returncode,
                                       'stdout': _stdout, 'stderr': _stderr}

        if obj.returncode and log_fail_as_error:
            LOG.error(m)
        else:
            LOG.debug(m)

        if obj.returncode and check_exit_code:
            raise RuntimeError(m)
    finally:
        # NOTE(termie): this appears to be necessary to let the subprocess
        #               call clean something up in between calls, without
        #               it two execute calls in a row hangs the second one
        greenthread.sleep(0)

    return return_stderr and (_stdout, _stderr) or _stdout

class TransMiddlebox(resource.Resource):

    PROPERTIES = (
        NAME, TYPE, INGRESS_NODE, EGRESS_NODE, INGRESS_IP, EGRESS_IP,
    ) = (
        'name', 'type', 'ingress_node', 'egress_node',
        'ingress_ip', 'egress_ip',
    )

    ATTRIBUTES = (
        NAME,
    )

    properties_schema = {
        NAME: properties.Schema(
            properties.Schema.STRING,
            _('Name of the middlebox.')
        ),
        TYPE: properties.Schema(
            properties.Schema.STRING,
            _('Type of the middlebox.')
        ),
        INGRESS_NODE: properties.Schema(
            properties.Schema.STRING,
            _('Ingress node id the middlebox.')
        ),
        EGRESS_NODE: properties.Schema(
            properties.Schema.STRING,
            _('Egress node id the middlebox.')
        ),
        INGRESS_IP: properties.Schema(
            properties.Schema.STRING,
            _('Ingress IP of the middlebox.')
        ),
        EGRESS_IP: properties.Schema(
            properties.Schema.STRING,
            _('Egress IP of the middlebox.')
        ),
        }

    attributes_schema = {
        NAME: attributes.Schema(
            _('Name of the service policy.')
        ),
        }

    def handle_create(self):
        name = self.properties.get(self.NAME)
        type = self.properties.get(self.TYPE)
        ingress_node = self.properties.get(self.INGRESS_NODE)
        ingress_ip = self.properties.get(self.INGRESS_IP)
        egress_node = self.properties.get(self.EGRESS_NODE)
        egress_ip = self.properties.get(self.EGRESS_IP)
        LOG.info('trans_mb: handle_create() is called')
        LOG.info('name=%s, type=%s, ingress=%s,%s, egress=%s,%s'
                 %(name,  type, ingress_node, ingress_ip, egress_node, egress_ip))

        with open(TMP_CONF,'w') as f:
            f.write('[%s]\n' % name)
            f.write('service_type = %s\n' % type)
            f.write('ingress_node = %s\n' % ingress_node)
            f.write('egress_node = %s\n' % egress_node)
            f.write('ingress_ip = %s\n' % ingress_ip)
            f.write('egress_ip = %s\n' % egress_ip)
            f.write('\n')

    def handle_delete(self):
        LOG.info('trans_mb: handle_delete() is called')

    def _resolve_attribute(self, name):
        if name == self.NAME:
            return self.properties.get(self.NAME)


class RoutedMiddlebox(resource.Resource):

    PROPERTIES = (
        NAME, TYPE, INGRESS_GW_ADDR, EGRESS_GW_ADDR, INGRESS_CIDR, EGRESS_CIDR,
    ) = (
        'name', 'type', 'ingress_gw_addr', 'egress_gw_addr',
        'ingress_cidr', 'egress_cidr',
    )

    ATTRIBUTES = (
        NAME,
    )

    properties_schema = {
        NAME: properties.Schema(
            properties.Schema.STRING,
            _('Name of the middlebox.')
        ),
        TYPE: properties.Schema(
            properties.Schema.STRING,
            _('Type of the middlebox.')
        ),
        INGRESS_GW_ADDR: properties.Schema(
            properties.Schema.STRING,
            _('Ingress gw ip address of the middlebox.')
        ),
        EGRESS_GW_ADDR: properties.Schema(
            properties.Schema.STRING,
            _('Egress node id the middlebox.')
        ),
        INGRESS_CIDR: properties.Schema(
            properties.Schema.STRING,
            _('Ingress ip cidr of the middlebox.')
        ),
        EGRESS_CIDR: properties.Schema(
            properties.Schema.STRING,
            _('Egress ip cidr of the middlebox.')
        ),
        }

    attributes_schema = {
        NAME: attributes.Schema(
            _('Name of the service policy.')
        ),
        }

    def handle_create(self):
        name = self.properties.get(self.NAME)
        type = self.properties.get(self.TYPE)
        ingress_cidr = self.properties.get(self.INGRESS_CIDR)
        ingress_gw_addr = self.properties.get(self.INGRESS_GW_ADDR)
        egress_cidr = self.properties.get(self.EGRESS_CIDR)
        egress_gw_addr = self.properties.get(self.EGRESS_GW_ADDR)
        LOG.info('routed_mb: handle_create() is called')
        LOG.info('name=%s, type=%s, ingress=%s,%s, egress=%s,%s'
                 %(name,  type, ingress_cidr, ingress_gw_addr, egress_cidr,
                   egress_gw_addr))

        with open(TMP_CONF, 'a') as f:
            f.write('[%s]\n' % name)
            f.write('service_type = %s\n' % type)
            f.write('ingress_cidr = %s\n' % ingress_cidr)
            f.write('egress_cidr = %s\n' % egress_cidr)
            f.write('ingress_gw_addr = %s\n' % ingress_gw_addr)
            f.write('egress_gw_addr = %s\n' % egress_gw_addr)
            f.write('\n')

    def handle_delete(self):
        LOG.info('routed_mb: handle_delete() is called')

    def _resolve_attribute(self, name):
        if name == self.NAME:
            return self.properties.get(self.NAME)


class ServicePolicy(resource.Resource):

    PROPERTIES = (
        NAME, SRC, DST, SERVICES, COMPUTE_NODE, SDN_CONTROLLER,
        BIDIRECTIONAL, DEPLOY, ADMIN_AUTH_URL, ADMIN_USERNAME,
        ADMIN_PASSWORD, ADMIN_TENANT_NAME, PROJECT_AUTH_URL,
        PROJECT_USERNAME, PROJECT_PASSWORD, PROJECT_TENANT_NAME,
    ) = (
        'name', 'src', 'dst', 'services', 'compute_node', 'sdn_controller',
        'bidirectional', 'deploy', 'admin_auth_url', 'admin_username',
        'admin_password', 'admin_tenant_name', 'project_auth_url',
        'project_username', 'project_password', 'project_tenant_name',
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
        SERVICES: properties.Schema(
            properties.Schema.LIST,
            _('List of service middleboxes.'),
            default=[],
            update_allowed=True
        ),
        COMPUTE_NODE: properties.Schema(
            properties.Schema.STRING,
            _('IP of the computer node.')
        ),
        SDN_CONTROLLER: properties.Schema(
            properties.Schema.STRING,
            _('IP of the sdn controller.')
        ),
        BIDIRECTIONAL: properties.Schema(
            properties.Schema.STRING,
            _('Whether to generate policy in both directions.')
        ),
        DEPLOY: properties.Schema(
            properties.Schema.STRING,
            _('Whether to deploy the generated policy.')
        ),
        ADMIN_AUTH_URL: properties.Schema(
            properties.Schema.STRING,
            _('Auth url for the admin.')
        ),
        ADMIN_USERNAME: properties.Schema(
            properties.Schema.STRING,
            _('Username for the admin.')
        ),
        ADMIN_PASSWORD: properties.Schema(
            properties.Schema.STRING,
            _('Password for the admin.')
        ),
        ADMIN_TENANT_NAME: properties.Schema(
            properties.Schema.STRING,
            _('Tenant name for the admin.')
        ),
        PROJECT_AUTH_URL: properties.Schema(
            properties.Schema.STRING,
            _('Auth url for the project.')
        ),
        PROJECT_USERNAME: properties.Schema(
            properties.Schema.STRING,
            _('Username for the project.')
        ),
        PROJECT_PASSWORD: properties.Schema(
            properties.Schema.STRING,
            _('Password for the project.')
        ),
        PROJECT_TENANT_NAME: properties.Schema(
            properties.Schema.STRING,
            _('Tenant name for the project.')
        ),
    }

    attributes_schema = {
        NAME: attributes.Schema(
            _('Name of the service policy.')
        ),
    }

    default_client_name = 'neutron'

    def handle_create(self):
        name = self.properties.get(self.NAME)
        src = self.properties.get(self.SRC)
        dst = self.properties.get(self.DST)
        services = self.properties.get(self.SERVICES)
        bidirectional = self.properties.get(self.BIDIRECTIONAL)
        deploy = self.properties.get(self.DEPLOY)
        compute_node = self.properties.get(self.COMPUTE_NODE)
        sdn_controller = self.properties.get(self.SDN_CONTROLLER)
        admin_auth_url = self.properties.get(self.ADMIN_AUTH_URL)
        admin_username = self.properties.get(self.ADMIN_USERNAME)
        admin_password = self.properties.get(self.ADMIN_PASSWORD)
        admin_tenant_name = self.properties.get(self.ADMIN_TENANT_NAME)
        project_auth_url = self.properties.get(self.PROJECT_AUTH_URL)
        project_username = self.properties.get(self.PROJECT_USERNAME)
        project_password = self.properties.get(self.PROJECT_PASSWORD)
        project_tenant_name = self.properties.get(self.PROJECT_TENANT_NAME)
        LOG.info('service_policy: handle_create() is called')
        LOG.info('name=%s, src=%s, dst=%s, services=%s, bidirectional=%s, '
                 'deploy=%s, compute_node=%s, '
                 'sdn_controller=%s, admin(user,pwd,tenant)=%s,%s:%s:%s, '
                 'project(user,pwd,tenant)=%s,%s:%s:%s'
        % (name, src, dst, ','.join([e.strip('[]') for e in services]), 'True' if
        bidirectional else 'False', 'True' if deploy else 'False',
           compute_node, sdn_controller, admin_auth_url, admin_username,
           admin_password, admin_tenant_name, project_auth_url,
           project_username, project_password, project_tenant_name))
        LOG.info('Write temp conf file into %s' %TMP_CONF)
        with open(TMP_CONF, 'a') as f:
            f.write('[DEFAULT]\n')
            f.write('src = %s\n' % src)
            f.write('dst = %s\n' % dst)
            f.write('services = %s\n' % ','.join([e.strip('[]') for e in services]))
            f.write('policy_name = %s\n' % name)
            if bidirectional.upper().startswith('F'):
                f.write('bidirectional = False\n')
            else:
                f.write('bidirectional = True\n')
            if deploy.upper().startswith('F'):
                f.write('deploy = False\n')
            else:
                f.write('deploy = True\n')
            f.write('compute_node = %s\n' % compute_node)
            f.write('sdn_controller = %s\n' % sdn_controller)
            f.write('\n')
            f.write('[ADMIN]\n')
            f.write('auth_url = %s\n' % admin_auth_url)
            f.write('username = %s\n' % admin_username)
            f.write('password = %s\n' % admin_password)
            f.write('tenant_name = %s\n' % admin_tenant_name)
            f.write('\n')
            f.write('[PROJECT]\n')
            f.write('auth_url = %s\n' % project_auth_url)
            f.write('username = %s\n' % project_username)
            f.write('password = %s\n' % project_password)
            f.write('tenant_name = %s\n' % project_tenant_name)
            f.write('\n')
        with open('/tmp/heatgen_trigger', 'w') as f:
            f.write('1\n')
            cmd = 'heatgen --config-file %s' %(TMP_CONF)
            f.write(cmd)
        # We cannot call heatgen in daemonlized prog as heatgen call popen(ssh)!
        #cmd = 'heatgen --config-file %s' %(TMP_CONF)
        #result, error = Popen(cmd, stdout=PIPE, stderr=PIPE,
        # shell=True).communicate()
        #if error:
        #    LOG.error('Tries %d, failed to call cmd %s, error_msg=%s\n' % (
        #        i, cmd, error))
        #else:
        #    LOG.info('cmd %s output is %s\n' % (cmd, result))


    def handle_delete(self):
        LOG.info('service_policy: handle_delete() is called')

    def _resolve_attribute(self, name):
        if name == self.NAME:
            return self.properties.get(self.NAME)

def resource_mapping():
    return {
        'OS::Neutron::TransMiddlebox': TransMiddlebox,
        'OS::Neutron::RoutedMiddlebox': RoutedMiddlebox,
        'OS::Neutron::ServicePolicy': ServicePolicy,
    }
