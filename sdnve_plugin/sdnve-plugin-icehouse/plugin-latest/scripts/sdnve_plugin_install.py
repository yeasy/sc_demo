#!/usr/bin/python

import sys
import os
from subprocess import Popen, PIPE, STDOUT


def execute(cmd, errorok=False):
    print "Executing %s\n" % cmd
    pdesc = Popen(cmd, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT,
                  close_fds=True)
    pdesc.wait()
    output = pdesc.stdout.read()
    retcode = pdesc.returncode
    if retcode != 0:
        print "FAILED executing %s" % cmd
        print output
        if not errorok:
            print "Failed, exiting..."
            exit()
    print "Done\n"


def basicChecks():
    path = os.getcwd() + "/../../plugin-latest"
    print path
    if not os.path.exists(path):
        print "Please run this program from the scripts directory "
        exit()


def upgradeChecks():
    # the config files/dirs must exist which are not being copied over
    plugin_exists = os.path.exists(
        "/etc/neutron/plugins/ibm/sdnve_neutron_plugin.ini")
    if (not plugin_exists):
        print "Cannot upgrade, cant find existing installation!"
        exit()
    return True


def upgrade():
    basicChecks()
    print "Performing upgrade checks..."
    upgradeChecks()
    # do the upgrade
    print "Step 3.2"
    cmd = "cp ../../plugin-archive/int_support/neutron-sdnve-agent /usr/bin/"
    execute(cmd)
    print "Step 3.3"
    cmd = "cp ../../plugin-archive/int_support/rc/neutron-sdnve-agent " \
          "/etc/init.d/"
    execute(cmd)
    print "Step 3.7"
    cmd = "rm -rf /usr/lib/python2.6/site-packages/neutron/plugins/ibm.old"
    execute(cmd)
    cmd = "mv /usr/lib/python2.6/site-packages/neutron/plugins/ibm " \
          "/usr/lib/python2.6/site-packages/neutron/plugins/ibm.old"
    execute(cmd)
    print "Step 3.8"
    cmd = "cp -r ../../plugin-latest/ibm " \
          "/usr/lib/python2.6/site-packages/neutron/plugins/"
    execute(cmd)
    # the following is for dhcp
    print "Step 3.9"
    cmd = "cp ../../plugin-latest/dhcp/sdnvedhcp.py " \
          "/usr/lib/python2.6/site-packages/neutron/agent/linux/"
    execute(cmd)
    print "sdnve plugin is upgraded, please restart neutron server, " \
          "using 'service neutron-server restart'"


def install():
    basicChecks()
    print "Performing upgrade checks..."
    if os.path.exists("/etc/neutron/plugins/ibm/sdnve_neutron_plugin.ini"):
        print "An existing sdnve install exists !, use 'upgrade' instead of " \
              "'install'"

        # exit()

    # do the upgrade
    print "Step 3.2"
    cmd = "cp ../../plugin-archive/int_support/neutron-sdnve-agent /usr/bin/"
    execute(cmd)
    print "Step 3.3"
    cmd = "cp ../../plugin-archive/int_support/rc/neutron-sdnve-agent " \
          "/etc/init.d/"
    execute(cmd)
    print "Step 3.4"
    cmd = "mkdir -p /etc/neutron/plugins/ibm"
    execute(cmd)
    print "Step 3.5"
    cmd = "cp ../../plugin-archive/int_support/sdnve_neutron_plugin.ini " \
          "/etc/neutron/plugins/ibm/"
    execute(cmd)

    print "Step 3.6"
    cmd = "ln -sf /etc/neutron/plugins/ibm/sdnve_neutron_plugin.ini " \
          "/etc/neutron/plugin.ini"
    execute(cmd)

    print "Step 3.7"
    cmd = "rm -rf /usr/lib/python2.6/site-packages/neutron/plugins/ibm.old"
    execute(cmd)
    cmd = "mv /usr/lib/python2.6/site-packages/neutron/plugins/ibm " \
          "/usr/lib/python2.6/site-packages/neutron/plugins/ibm.old"
    execute(cmd)
    print "Step 3.8"
    cmd = "cp -r ../../plugin-latest/ibm " \
          "/usr/lib/python2.6/site-packages/neutron/plugins/"
    execute(cmd)

    # the following is for dhcp
    print "Step 3.9"
    cmd = "cp ../../plugin-latest/dhcp/sdnvedhcp.py " \
          "/usr/lib/python2.6/site-packages/neutron/agent/linux/"
    execute(cmd)

    print "sdnve plugin is installed, please restart neutron-server & " \
          "possibly neutron-dhcp-agent"


def usage():
    print "Usage: ./sdnve_plugin_install.py <install|upgrade>"
    exit()


def main():
    if len(sys.argv) < 2:
        usage()
    if sys.argv[1] not in ["install", "upgrade"]:
        usage()
    if sys.argv[1] == "install":
        install()
    if sys.argv[1] == "upgrade":
        upgrade()


if __name__ == "__main__":
    main()

