Setup the xgs demo
===

The xgs demo include two parts: setup a project in OpenStack and add service 
policy into the project.


#Prerequisite
* [OpenStack] (http://openstack.org) IceHouse version
	* aggregated zone az1: a compute node
	* aggregated zone az2: a control node
	* vm image ubuntu-pc.img: user's vm
	* vm image ISNP_5.2_20140502-1219_personal_compat.qcow2: trans_mb vm
	* vm image any routing os: routed_mb vm
* [heatgen](https://github.com/yeasy/heatgen)

#Setup the project

##Option 1: Utilize shell script
``` ./xgs_init.sh ``` and  ``` ./xgs_clean.sh ```

##Option 2: Utilize HEAT
```./heat_run.sh``` will call the local template files to finish the provision.


#Insert service policy

##Option 1: Utilize heatgen
Create a configuration file and let heatgen parse it.

##Option 2: Utilize HEAT
```./heat_run.sh``` will call the local template files to finish the provision.

