#!/bin/bash

# check the user that run this script
id
echo "----fastboot devices list from /sys/bus/usb/devices start----"
fastboot_devices=""
#ls /sys/bus/usb/devices/*/serial | while read -r device; do
ls /sys/bus/usb/drivers/usb/*/serial | while read -r device; do
    basedir=$(dirname ${device})
    realpath_basedir=$(realpath ${basedir})
    fastboot_devices="${fastboot_devices} ${realpath_basedir}"
    basedir_name=$(basename ${basedir})
    #interface_dir="/sys/bus/usb/devices/${basedir_name}/${basedir_name}:1.*"
    ls -1d /sys/bus/usb/devices/${basedir_name}/${basedir_name}:1.* 2>/dev/null| while read -r interface; do
        bInterfaceClass=$(cat ${interface}/bInterfaceClass)
        bInterfaceSubClass=$(cat ${interface}/bInterfaceSubClass)
        bInterfaceProtocol=$(cat ${interface}/bInterfaceProtocol)
        if [ "X${bInterfaceClass}" = "Xff" ] && \
            [ "X${bInterfaceSubClass}" = "X42" ] && \
            [ "X${bInterfaceProtocol}" = "X03" ]; then
            serial=$(cat ${device})
            if [ ! -f ${interface}/interface ]; then
                echo "${serial} no-interface-fastboot ${device}"
            else
                echo "${serial} interface-$(cat ${interface}/interface) ${device}"
            fi
        fi
    done
done
echo "----fastboot devices list from /sys/bus/usb/devices end----"
echo "----fastboot devices list from fastboot devices command start----"
fastboot devices
echo "----fastboot devices list from fastboot devices command end----"
# check the owner and group of the android devices
echo "----list usb devices owner and group start----"
ls -l /dev/bus/usb/*/*
echo "----list usb devices owner and group end----"
fastboot_devices=$(echo ${fastboot_devices})
if [ -n "${fastboot_devices}" ]; then
    for device in ${fastboot_devices}; do
        echo add |tee ${device}/uevent
        # /sys/bus/usb/drivers/usb/bind and /sys/bus/usb/drivers/usb/unbind
    done
fi
echo "----list usb devices owner and group after regenate uevent start----"
ls -l /dev/bus/usb/*/*
echo "----list usb devices owner and group after regenate uevent end----"
