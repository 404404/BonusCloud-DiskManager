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

#环境检测，检测是否为多盘
disk_support=$(cat /lib/systemd/system/bxc-node.service | grep -q 'devoff' ;echo $?)
if [[ ${disk_support} == 1 ]]; then 
    printf "Enabling multi-disk function, please wait... \n"
	printf "正在打开多盘功能，请稍候... \n"
	sed -i  's/nodeapi/node /nodeapi/node --devoff /1' /lib/systemd/system/bxc-node.service
	systemctl daemon-reload
	systemctl restart bxc-node
else
	printf "系统环境已经支持多盘，无需操作... \n"
fi

vg_check=$(vgs | grep -q "BonusVolGroup" ;echo $?)
[[ ${vg_check} == 1 ]] && vgcreate BonusVolGroup
vgreduce BonusVolGroup --removemissing --force

roots_disk=$(ls /dev/* | grep "${root_disk}" | sed -n 1p)
roots_part=$(fdisk -l | grep "${roots_disk}" | grep "LVM" | awk '{print $1}')
vg_have=$(pvs 2>/dev/null | grep "${roots_disk}" | grep -q "BonusVolGroup" ;echo $?)
pv_have=$(fdisk -l | grep "${roots_disk}" | grep -q "LVM" ;echo $?)
if [[ ${pv_have} == 0 && ${vg_have} == 1 ]]; then
    echowarn "\nNow Processing / 正在处理： "
    echoinfo "${roots_disk} \n"
    pvcreate ${roots_part}
    vgextend BonusVolGroup ${roots_part}
fi

for sd in $(ls /dev/* | grep -E '((sd[a-z]$)|(vd[a-z]$)|(hd[a-z]$)|(nvme[0-9][a-z][0-9]$))' | grep -v "${root_disk}" | sort); do
	vg_have=$(pvs 2>/dev/null | grep "${sd}" | grep -q "BonusVolGroup" ;echo $?)
	echowarn "\nNow Processing / 正在处理： "
	echoinfo "${sd} \n"
	if [[ ${vg_have} == 0 ]]; then
	    printf "Detected that the disk has created a VG volume, do you need to format it? \n"
		echoerr "Formatting will clear all the data on the disk, please choose carefully. \n"
		printf "检测到该磁盘已创建VG卷，是否需要格式化？"
		echoerr "格式化将会清除该磁盘上所有的数据，请谨慎选择。默认N \n"
		read -r -p "[Y / Default N]:  " choose
		case ${choose} in
            Y|y|YES|YEs|YeS|yES|Yes|yEs|yeS|yes ) echo -e "o\nw\n" | fdisk ${sd} ;;
			* ) printf "Skip! \n" && continue ;;
        esac
	fi
	#清除磁盘残留信息，防止不能做lvm
	wipefs -a ${sd}
	pvcreate ${sd}
	
	vgextend BonusVolGroup ${sd}
done

vgreduce BonusVolGroup --removemissing --force

free_space=$(vgdisplay | grep 'VG Size' | awk '{print $3,$4}' | sed -r 's/\i//g')
if [[ ${free_space} > 100 ]]; then 
    echowarn "\nTotal cache space / 总可用缓存空间: "
	echoinfo "${free_space} \n"

	disk_support=$(cat /lib/systemd/system/bxc-node.service | grep -q 'devoff' ;echo $?)
	echowarn "Multi-disk support / 多盘支持: "
	if [[ ${disk_support} == 0 ]]; then
	    echoinfo "√ \n"
	else
	    echoerr "× \n"
	fi

	root_pv=$(pvs 2>/dev/null | grep -q "${roots_disk}" ;echo $?)
	root_vg=$(pvs 2>/dev/null | grep "${roots_disk}" | grep -q "BonusVolGroup" ;echo $?)
	echowarn "${roots_disk}: \t"
	if [[ ${root_pv} == 0 && ${root_vg} == 0 ]]; then
		echoinfo "√ \t root disk \n"
	else
	    echoinfo "root disk \n"
	fi

	for sd in $(ls /dev/* | grep -E '((sd[a-z]$)|(vd[a-z]$)|(hd[a-z]$)|(nvme[0-9][a-z][0-9]$))' | grep -v "${root_disk}" | sort); do
	    pv_have=$(pvs 2>/dev/null | grep -q "${sd}" ;echo $?)
        vg_have=$(pvs 2>/dev/null | grep "${sd}" | grep -q "BonusVolGroup" ;echo $?)
	    echowarn "${sd}: \t"
	    if [[ ${pv_have} == 0 && ${vg_have} == 0 ]]; then
	        echoinfo "Success √ \n"
	    else 
	        echoerr "Failed × \t Please try again! \n"
	    fi
    done
else
    echoerr "The available space is less than 100G, please replace the larger disk and try again! \n"
	echoerr "可用空间达不到最低要求，请更换更大的磁盘后重试! \n"
fi