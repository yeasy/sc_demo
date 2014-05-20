#!/bin/bash
#
DIR="sdnve-plugin-icehouse"

[[ $# -lt 1 ]] && echo "Please give a param: 0 for remove; 1 for install" && exit 0;


EXEC="need_init_empty.sh"
CONTROLS=("9.186.105.110")
#COMPUTES=("9.186.105.49" "192.168.100.102")
COMPUTES=("9.186.105.49")

if [ $1 -eq 1 ]; then
    echo "###Install sdnve plugins"
    EXEC="installplugin.sh"
else
    echo "###Uninstall sdnve plugins"
    EXEC="removeplugin.sh"
fi

for n in ${COMPUTES[@]}; do
    echo ">>>Copy files to compute node $n"
    scp -r ${DIR} $n:/root/ >/dev/null
    ssh $n "pushd /root/${DIR}/; bash ${EXEC} 0"
done

for n in ${CONTROLS[@]}; do
    echo ">>>Copy files to control node $n"
    scp -r ${DIR} $n:/root/ >/dev/null
    if [ $1 -eq 0 ]; then
        ssh $n "ovs-vsctl del-controller br-int"
    fi
    ssh $n "pushd /root/${DIR}/; bash ${EXEC} 1"
done


echo "###Done."
exit
