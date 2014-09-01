#!/bin/sh
mysql -uroot
show databases;
create database sdnve_neutron;
grant all privileges on sdnve_neutron.* to neutron@"%";

