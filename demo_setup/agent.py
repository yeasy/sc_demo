#!`which python`
# This agent watch /tmp/heatgen_trigger, and run the inside command to call
# heatgen. This is a temporary solution as in heat-engine, it cannot access
# the ssh id file of root, and cannot get port information from the computer
# node.

import sys
import time
from subprocess import Popen, PIPE


def get_time():
    time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(time.time()))


def run_cmd(cmd):
    #TMP_CONF = '/tmp/temp_config.conf'
    #cmd = 'heatgen --config-file %s' %(TMP_CONF)

    print '[%s]run cmd=%s' % (get_time(), cmd)
    result, error = Popen(cmd, stdout=PIPE, stderr=PIPE,
                          shell=True).communicate()
    print 'result=', result
    print 'error=', error


if __name__ == "__main__":
    for i in range(1000):
        time.sleep(5)
        s = '0'
        try:
            with open('/tmp/heatgen_trigger', 'r') as f:
                s = f.readline()
                print "[%s]get firstline=%s from trigger file" % (get_time(), s)
                if s.startswith('1'):
                    cmd = f.readline()
                    print "[%s]get cmd=%s from trigger file" % (get_time(), cmd)
                    time.sleep(5)
                    run_cmd(cmd)
            if s.startswith('1'):
                with open('/tmp/heatgen_trigger', 'w') as f:
                    f.write('0')
                    s = '0'
        except IOError:
            continue
    exit()

    #from  oslo.config import cfg
    #common_opts = [ cfg.StrOpt('bind_host', default='0.0.0.0', help='IP
    # address to listen on'), cfg.IntOpt('bind_port', default=9292,
    # help='Port number to listen on') ]

    #CONF = cfg.CONF
    #CONF.register_opts(common_opts)
    #CONF.register_cli_opts(common_opts)

    #CONF(args=sys.argv[1:])

    #print CONF.keys()
    #print CONF.values()


