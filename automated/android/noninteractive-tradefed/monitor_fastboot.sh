#!/bin/sh -x
while true; do
    date
    echo "Run fastboot continue to wait and reboot the device again"
    fastboot continue
    sleep 30
done
