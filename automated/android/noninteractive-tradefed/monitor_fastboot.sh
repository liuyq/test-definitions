#!/bin/sh -x
while true;
do
    date
    if [ -f /lava-lxc/*boot*.img ]; then
        # for lxc container method
        fastboot boot /lava-lxc/*boot*.img
    else
        # for docker method
        fastboot boot /lava-downloads/*boot*.img
    fi
    sleep 30
done
