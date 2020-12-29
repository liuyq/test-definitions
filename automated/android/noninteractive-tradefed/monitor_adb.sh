#!/bin/sh -x
while true;
do
    date
    adb shell ifconfig
    sleep 30
done
