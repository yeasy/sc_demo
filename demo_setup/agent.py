#!`which python`

import sys
import time
from subprocess import Popen, PIPE


def run_cmd(cmd):
    #TMP_CONF = '/tmp/temp_config.conf'
    #cmd = 'heatgen --config-file %s' %(TMP_CONF)

    result, error = Popen(cmd, stdout=PIPE, stderr=PIPE, shell=True).communicate()
    #print 'result=',result
    #print 'error=',error

if __name__ == "__main__":
    for i in range(1000):
        time.sleep(5)
        s = '0'
        try:
            with open('/tmp/heatgen_trigger', 'r') as f:
                s = f.readline()
                if s.startswith('1'):
                    cmd = f.readline()
                    #print "run %s" %cmd
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
    # address to listen on'), cfg.IntOpt('bind_port', default=9292, help='Port number to listen on') ]

    #CONF = cfg.CONF
    #CONF.register_opts(common_opts)
    #CONF.register_cli_opts(common_opts)

    #CONF(args=sys.argv[1:])

    #print CONF.keys()
    #print CONF.values()


