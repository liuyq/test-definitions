#!/bin/sh -x
while true; do
    date
    echo "Run fastboot continue to wait and reboot the device again"
    # fastboot continue # still not supported for all platforms, like db845c, x15
    if [ -f /lava-lxc/*boot*.img ]; then
        # for lxc container method
        fastboot boot /lava-lxc/*boot*.img
    elif [ -f /lava-downloads/*boot*.img ]; then
        # for docker method
        fastboot boot /lava-downloads/*boot*.img
    else
        echo "No boot image found under /lava-lxc and /lava-downloads, please check and try again!"
        exit 1
    fi
    sleep 30
done
