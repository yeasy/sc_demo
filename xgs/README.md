Setup the xgs demo
===

The xgs demo include two parts: setup a project in openstack and add service 
policy into the project.


#Prerequisite
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

