#!/usr/bin/env bash

echoerr() { 
    printf "\033[1;31m$1\033[0m" 
}
echoinfo() { 
    printf "\033[1;32m$1\033[0m"
}
echowarn() { 
    printf "\033[1;33m$1\033[0m"
}

#获取系统盘符，应对系统盘不是sda的情况
root_type=$(lsblk -ar 2>>/dev/null | grep -w "/" | awk '{print $(NF-1)}')
root_name=$(lsblk -ar 2>>/dev/null | grep -w "/" | awk '{print $1}')
root_disk=""
if [[ x"${root_type}" == x"lvm" ]]; then
    root_vg_name=$(echo ${root_name} | awk -F- '{print $1}')
    root_disk=$(pvs 2>>/dev/null | grep "${root_vg_name}" | awk '{print $1}' | sed 's/[0-9]//;s/\/dev\///')
else
    disk_type=$(lsblk -ar 2>>/dev/null | grep -w "/" | awk '{print $1}' | grep -q "nvme" ;echo $?)
    if [[ ${disk_type} == 0 ]]; then 
        root_disk=$(lsblk -ar 2>>/dev/null | grep -w "/" | awk '{print $1}' | cut -b 1-7)
    else
        root_disk=$(lsblk -ar 2>>/dev/null | grep -w "/" | awk '{print $1}' | sed 's/[0-9]//')
    fi
fi

if [[ -z "${root_disk}" ]]; then
    echoerr "Can't find the root disk, exit"
    exit 1
fi

roots_disk=$(ls /dev/* | grep "${root_disk}" | sed -n 1p)
vg_have=$(pvs 2>/dev/null | grep "${roots_disk}" | grep -q "BonusVolGroup" ;echo $?)
echowarn "\nNow Processing / 正在处理： "
echoinfo "${roots_disk} \n"

if [[ ${vg_have} == 1 ]]; then 
    printf "Whether to add the remaining space of the system disk to the cache space? Press Ctrl + C to cancel. \n"
    echowarn "After the operation, the device will restart to make the operation take effect. \n"
    echowarn "After restarting, please run hdd.sh to complete the remaining operations. Press Enter to continue.\n"
    printf "是否将系统盘剩余空间加入缓存空间？ 按 Ctrl + C 可取消。 \n"
    echowarn "操作后设备将会重启使操作生效，重启后请运行 hdd.sh 完成剩余操作。继续执行请按回车。"
    read -r -p "" choose
    case ${choose} in
        * ) echo -e "n
			p
			

			t

			8e
			w
			" | fdisk ${roots_disk} ;;
    esac
    reboot
fi
