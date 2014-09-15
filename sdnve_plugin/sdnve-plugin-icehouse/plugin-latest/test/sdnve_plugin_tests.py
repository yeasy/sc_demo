#!/usr/bin/python

import sys
import os
from subprocess import Popen, PIPE, STDOUT
import time

def execute(cmd, errorok=True):
    print "Executing %s\n"%cmd
    pdesc = Popen(cmd, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True)
    pdesc.wait()
    output = pdesc.stdout.read()
    retcode = pdesc.returncode
    if retcode != 0:
        print "FAILED executing %s"%cmd
        print output
        if not errorok:
            print "Failed, exiting..."
            exit()
        else:
            print output
            errno=1
            return None
    print output
    return output

vm_image_id = None
errno=0

def keystone_get_id(objname, name):
    cmd = "keystone %s-list"%(objname)
    output = execute(cmd)
    lis = output.split("\n")
    for i in lis:
        toks = i.split()
        print toks
        if len(toks)>=3 and toks[3] == name:
            return toks[1]
    return None

def get_id(sdn_tenant_id, objname, name):
    cmd = "neutron %s-list --tenant-id=%s"%(objname,sdn_tenant_id)
    output = execute(cmd)
    lis = output.split("\n")
    for i in lis:
        toks = i.split()
        print toks
        if len(toks)>=3 and toks[3] == name:
            return toks[1]
    return None

def get_id_first(sdn_tenant_id, objname):
    cmd = "neutron %s-list --tenant-id=%s"%(objname,sdn_tenant_id)
    output = execute(cmd)
    lis = output.split("\n")
    for i in lis:
        toks = i.split()
        print toks
        if len(toks)>=6 and toks[1] != "id":
            return toks[1]
    return None

def tenant_create(name):
    cmd = "keystone tenant-create --name %s --description %s"%(name,"SDNVE-OVERLAY")    
    execute(cmd)
    time.sleep(1)
    tenant_id = keystone_get_id("tenant",name)
    print "Tenant id is %s"%tenant_id
    cmd = "keystone user-role-add --user admin --role admin --tenant %s"%tenant_id
    execute(cmd)
    return tenant_id

def tenant_delete(name):
    cmd = "keystone tenant-delete %s"%(name)    
    execute(cmd)
    time.sleep(1)

def create_net(sdn_tenant_id, name, shared="", external=""):
    cmd = "neutron net-create %s %s %s --tenant-id=%s"%(name,shared,external,sdn_tenant_id)
    execute(cmd)
    time.sleep(1)

def delete_net(sdn_tenant_id, name):
    cmd = "neutron net-delete %s --tenant-id=%s"%(name,sdn_tenant_id)
    execute(cmd)
    time.sleep(1)


def create_subnet(sdn_tenant_id, net, name, subnet, dhcp=""):
    cmd = "neutron subnet-create %s %s --name %s %s --tenant-id=%s"%(net,subnet,name, dhcp, sdn_tenant_id)
    execute(cmd)
    time.sleep(1)

def delete_subnet(sdn_tenant_id, name):
    cmd = "neutron subnet-delete %s --tenant-id=%s"%(name,sdn_tenant_id)
    execute(cmd)
    time.sleep(1)

def router_create(sdn_tenant_id, name):
    cmd = "neutron router-create %s --tenant-id=%s"%(name,sdn_tenant_id)
    execute(cmd)
    time.sleep(1)

def router_delete(sdn_tenant_id, name):
    cmd = "neutron router-delete %s --tenant-id=%s"%(name,sdn_tenant_id)
    execute(cmd)
    time.sleep(1)

def router_interface_add(sdn_tenant_id, name,subnet):
    cmd = "neutron router-interface-add %s %s --tenant-id=%s"%(name,subnet, sdn_tenant_id)
    execute(cmd)
    time.sleep(1)

def router_interface_delete(sdn_tenant_id,name,subnet):
    cmd = "neutron router-interface-delete %s %s --tenant-id=%s"%(name,subnet, sdn_tenant_id)
    execute(cmd)
    time.sleep(1)

def router_gateway_set(sdn_tenant_id,router, subnet):
    cmd = "neutron router-gateway-set %s %s --tenant-id=%s"%(router,subnet,sdn_tenant_id)
    execute(cmd)
    time.sleep(1)


def router_gateway_clear(sdn_tenant_id,router):
    cmd = "neutron router-gateway-clear %s --tenant-id=%s"%(router,sdn_tenant_id)
    execute(cmd)
    time.sleep(1)

def floatingip_create(sdn_tenant_id,net):
    cmd = "neutron floatingip-create %s --tenant-id=%s"%(net, sdn_tenant_id)
    execute(cmd)
    time.sleep(1)

def floatingip_assoc(sdn_tenant_id,fipid, portid):
    cmd = "neutron floatingip-associate %s %s --tenant-id=%s"%(fipid, portid, sdn_tenant_id)
    execute(cmd)
    time.sleep(1)

def floatingip_disassoc(sdn_tenant_id,fipid):
    cmd = "neutron floatingip-disassociate %s --tenant-id=%s"%(fipid, sdn_tenant_id)
    execute(cmd)
    time.sleep(1)

def floatingip_delete(sdn_tenant_id,fipid):
    cmd = "neutron floatingip-delete %s --tenant-id=%s"%(fipid, sdn_tenant_id)
    execute(cmd)
    time.sleep(1)

def port_create(sdn_tenant_id,name, net, fixedip, subnetid):
    cmd = "neutron port-create --name %s --fixed-ip subnet_id=%s,ip_address=%s --tenant-id=%s %s" %(name,subnetid,fixedip,sdn_tenant_id,net)
    execute(cmd)
    time.sleep(1)

def port_delete(sdn_tenant_id,name):
    cmd = "neutron port-delete %s" %(name)
    execute(cmd)
    time.sleep(1)
    

def nova_boot(sdn_tenant_id,name,netid=None,portid=None):
    if netid:
        cmd = "nova --os-tenant-id %s boot --flavor 1 --image %s --nic net-id=%s %s"%(sdn_tenant_id,vm_image_id,netid,name)
    if portid:
        cmd = "nova --os-tenant-is %s boot --flavor 1 --image %s --nic port-id=%s %s"%(sdn_tenant_id,vm_image_id,portid,name)
    execute(cmd)

def nova_delete(sdn_tenant_id,name):
    cmd = "nova --os-tenant-id %s delete %s" %(sdn_tenant_id, name)
    execute(cmd)
    time.sleep(5)

def nova_wait_boot(sdn_tenant_id,name, state, retries=10):
    global errno
    cmd = "nova --os-tenant-id %s list" %(sdn_tenant_id)
    for i in range(retries):
        out = execute(cmd)
        lis = out.split("\n")
        for line in lis:
            toks = line.split()
            if len(toks) >= 5 and toks[3] == name and toks[5] == state:
                return
        time.sleep(5)
    # failed
    errno=1
    
                

def shared_net_test():

    global errno
    print "Starting shared net tests"
    errno = 0

    sdn_tenant_id = tenant_create("sn_test_tenant")
    sdn_tenant_id1 = tenant_create("sn_test_tenant1")


    create_net(sdn_tenant_id,"a1",shared="--shared")
    create_subnet(sdn_tenant_id,"a1","as1","10.0.1.0/24")

    netid = get_id(sdn_tenant_id,"net","a1")
    nova_boot(sdn_tenant_id,"vm1",netid=netid)

    nova_wait_boot(sdn_tenant_id,"vm1", "ACTIVE")

    nova_boot(sdn_tenant_id1,"vm2",netid=netid)

    nova_wait_boot(sdn_tenant_id1,"vm2", "ACTIVE")

    time.sleep(5)

    nova_delete(sdn_tenant_id,"vm1")
    time.sleep(5)
    nova_delete(sdn_tenant_id1,"vm2")
    time.sleep(5)

    delete_subnet(sdn_tenant_id,"as1")
    delete_net(sdn_tenant_id,"a1")

    tenant_delete("sn_test_tenant")
    tenant_delete("sn_test_tenant1")

    if errno:
        print "FAILED shared net tests"
        exit()
    else:
        print "PASSED shared net tests"


def dedicated_net_test():

    global errno
    errno = 0

    print "Starting dedicated net tests"

    sdn_tenant_id = tenant_create("dn_test_tenant")
    

    create_net(sdn_tenant_id,"a1")
    create_subnet(sdn_tenant_id,"a1","as1","10.0.1.0/24")

    netid = get_id(sdn_tenant_id,"net","a1")
    nova_boot(sdn_tenant_id,"vm1",netid=netid)

    nova_wait_boot(sdn_tenant_id,"vm1", "ACTIVE")

    router_create(sdn_tenant_id,"r1")
    router_interface_add(sdn_tenant_id,"r1","as1")

    create_net(sdn_tenant_id,"x1","","--router:external=True")
    create_subnet(sdn_tenant_id,"x1","xs1","1.1.1.0/24")

    router_gateway_set(sdn_tenant_id,"r1","x1")

    subnetid = get_id(sdn_tenant_id,"subnet","as1")
    port_create(sdn_tenant_id,"p1","a1","10.0.1.100",subnetid)

    port_id = get_id(sdn_tenant_id,"port","p1")
    
    floatingip_create(sdn_tenant_id,"x1")
    fipid = get_id_first(sdn_tenant_id,"floatingip")
    floatingip_assoc(sdn_tenant_id,fipid, port_id)
    
    time.sleep(2)
    floatingip_disassoc(sdn_tenant_id,fipid)
    floatingip_delete(sdn_tenant_id,fipid)

    port_delete(sdn_tenant_id,"p1")

    router_gateway_clear(sdn_tenant_id,"r1")
    router_interface_delete(sdn_tenant_id,"r1","as1")
    router_delete(sdn_tenant_id,"r1")
    
    nova_delete(sdn_tenant_id,"vm1")

    delete_subnet(sdn_tenant_id,"as1")
    delete_net(sdn_tenant_id,"a1")

    delete_subnet(sdn_tenant_id,"xs1")
    delete_net(sdn_tenant_id,"x1")

    tenant_delete("dn_test_tenant")

    if errno:
        print "FAILED dedicated net tests"
        exit()
    else:
        print "Passed dedicated net tests"

def usage():
    print "Usage: ./sdnve_plugin_tests.py <vm-image-id-to-use-in-tests>"
    print "run this test-suite at the controller host"
    exit()                

def main():
    global vm_image_id
    if len(sys.argv) < 2:
        usage()
    vm_image_id = sys.argv[1]
    
    dedicated_net_test()
    time.sleep(5)
    shared_net_test()

if __name__ == "__main__":
    main()

