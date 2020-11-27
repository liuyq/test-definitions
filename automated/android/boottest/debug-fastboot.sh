#!/bin/bash

# check the user that run this script
id
echo "----fastboot devices list from /sys/bus/usb/devices start----"
fastboot_devices=""
devpaths=""
#ls /sys/bus/usb/devices/*/serial | while read -r device; do
ls /sys/bus/usb/drivers/usb/*/serial | while read -r device; do
    basedir=$(dirname ${device})
    realpath_basedir=$(realpath ${basedir})
    basedir_name=$(basename ${basedir})
    #interface_dir="/sys/bus/usb/devices/${basedir_name}/${basedir_name}:1.*"
    ls -1d /sys/bus/usb/devices/${basedir_name}/${basedir_name}:1.* 2>/dev/null| while read -r interface; do
        bInterfaceClass=$(cat ${interface}/bInterfaceClass)
        bInterfaceSubClass=$(cat ${interface}/bInterfaceSubClass)
        bInterfaceProtocol=$(cat ${interface}/bInterfaceProtocol)
        devnum=$(cat ${interface}/devnum)
        busnum=$(cat ${interface}/busnum)
        if [ "X${bInterfaceClass}" = "Xff" ] && \
            [ "X${bInterfaceSubClass}" = "X42" ] && \
            [ "X${bInterfaceProtocol}" = "X03" ]; then
            serial=$(cat ${device})
            if [ ! -f ${interface}/interface ]; then
                echo "${serial} no-interface-fastboot ${device}"

                fastboot_devices="${fastboot_devices} ${realpath_basedir}"

                busnum=$(printf "%03d" ${busnum})
                devnum=$(printf "%03d" ${devnum})
                devpath="/dev/bus/usb/${busnum}/${devnum}"
                devpaths="${devpaths} ${devpath}"
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

if [ "$(id -ru)" -eq 0 ]; then
    ## chown the group to plugdev for fastboot devices
    devpaths=$(echo ${devpaths})
    if [ -n "${devpaths}" ]
        for devpath in ${devpaths}; do
            echo "chown group for ${devpath}"
            chown :plugdev ${devpath}
        done
    fi
    echo "----list usb devices owner and group after chown group to plugdev start----"
        ls -l /dev/bus/usb/*/*
    echo "----list usb devices owner and group after chown group to plugdev end----"

    # try to regenerate the uevent for fastboot devices
    fastboot_devices=$(echo ${fastboot_devices})
    if [ -n "${fastboot_devices}" ]; then
        for device in ${fastboot_devices}; do
            echo "regenerate uevent for ${device}"
            echo add |tee ${device}/uevent
            # /sys/bus/usb/drivers/usb/bind and /sys/bus/usb/drivers/usb/unbind
        done
    fi
    echo "----list usb devices owner and group after regenate uevent start----"
    ls -l /dev/bus/usb/*/*
    echo "----list usb devices owner and group after regenate uevent end----"
    echo "----fastboot devices list from fastboot devices command after chown group and uenent regenerate start----"
    fastboot devices
    echo "----fastboot devices list from fastboot devices command after chown group and uenent regenerate end----"
fi
