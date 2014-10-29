#!`which python`
# -*- coding: utf8 -*-
# This agent watch TRIGGER_FILE, and run the inside command to call
# heatgen. This is a temporary solution as in heat-engine, it cannot access
# the ssh id file of root, and cannot get port information from the computer
# node.

import logging
import logging.handlers
import sys
import time
from subprocess import Popen, PIPE


LOG_FILE = '/tmp/sc_demo_agent.log'
TRIGGER_FILE = '/tmp/sc_demo_agent.trigger'
handler = logging.handlers.RotatingFileHandler(LOG_FILE, maxBytes=1024 * 1024,
                                               backupCount=5)  # handler

fmt = '[%(asctime)s][%(name)s][%(levelname)s] %(filename)s:%(lineno)s - %(' \
      'message)s'
handler.setFormatter(logging.Formatter(fmt))  # add formatter to handler

logger = logging.getLogger('heatgen_agent')  # get logger
logger.addHandler(handler)  # add handler to logger
logger.setLevel(logging.DEBUG)


# deprecated
def get_time():
    return time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(time.time()))

def run_cmd(cmd):
    #TMP_CONF = '/tmp/temp_config.conf'
    #cmd = 'heatgen --config-file %s' %(TMP_CONF)

    logger.info('run cmd="%s"' % (cmd))
    result, error = Popen(cmd, stdout=PIPE, stderr=PIPE,
                          shell=True).communicate()
    if result:
        logger.debug('popen result="%s"' % result)
    if error:
        logger.debug('popen error="%s"' % error)

if __name__ == "__main__":
    logger.info('===agent started===')
    for i in range(1000):
        sys.stdout.flush()
        time.sleep(3)
        s = '0'
        try:
            with open(TRIGGER_FILE, 'r') as f:
                s = f.readline()
                logger.debug('From %s get headline="%s"' % (TRIGGER_FILE,s))
                if s.startswith('1'):
                    cmd = f.readline()
                    logger.debug('From %s get cmd="%s"' % (TRIGGER_FILE,cmd))
                    time.sleep(15)
                    run_cmd(cmd)
            if s.startswith('1'):
                with open(TRIGGER_FILE, 'w') as f:
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
