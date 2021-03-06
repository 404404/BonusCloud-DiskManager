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

#环境检测，检测是否为多盘
disk_support=$(cat /lib/systemd/system/bxc-node.service | grep -q 'devoff' ;echo $?)
if [[ ${disk_support} == 1 ]]; then 
    printf "Enabling multi-disk function, please wait... \n"
	printf "正在打开多盘功能，请稍候... \n"
	sed -i 's/node --logtostderr/node --devoff --logtostderr/g' /lib/systemd/system/bxc-node.service
	systemctl daemon-reload
	systemctl restart bxc-node.service
else
	printf "系统环境已经支持多盘，无需操作... \n"
fi

vg_check=$(vgs | grep -q "BonusVolGroup" ;echo $?)
[[ ${vg_check} == 1 ]] && vgcreate BonusVolGroup
vgreduce BonusVolGroup --removemissing --force

for sd in $(fdisk -l | grep -E 'Disk /dev/((sd[a-z]$)|(vd[a-z]$)|(hd[a-z]$)|(nvme[0-9][a-z][0-9]$))' | sed 's/Disk //g' | sed 's/\://g' | awk '{print $1}' | sort); do
	vg_have=$(pvs 2>/dev/null | grep "${sd}" | grep -q "BonusVolGroup" ;echo $?)
	echowarn "Now Processing / 正在处理： "
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
	wipefs -a ${sd} 2>/dev/null
	pvcreate ${sd} 2>/dev/null
	vgextend BonusVolGroup ${sd} 2>/dev/null
done

vgreduce BonusVolGroup --removemissing --force

free_space=$(vgdisplay | grep 'VG Size' | awk '{print $3,$4}' | sed -r 's/\i//g')
if [[ ${free_space} > 101 ]]; then 
    echowarn "\nTotal cache space / 总可用缓存空间: "
	echoinfo "${free_space} \n"

	disk_support=$(cat /lib/systemd/system/bxc-node.service | grep -q 'devoff' ;echo $?)
	echowarn "Multi-disk support / 多盘支持: "
	if [[ ${disk_support} == 0 ]]; then
	    echoinfo "√ \n"
	else
	    echoerr "× \n"
	fi

	for sd in $(fdisk -l | grep -E 'Disk /dev/((sd)|(vd)|(hd))' | sed 's/Disk //g' | sed 's/\://g' | awk '{print $1}' | sort); do
	    pv_have=$(pvs 2>/dev/null | grep -q "${sd}" ;echo $?)
        vg_have=$(pvs 2>/dev/null | grep "${sd}" | grep -q "BonusVolGroup" ;echo $?)
	    echowarn "${sd} \t"
	    if [[ ${pv_have} == 0 && ${vg_have} == 0 ]]; then
	        echoinfo "Success √ \n"
	    else 
	        echoerr "Failed × \t Please try again! \n"
	    fi
    done
else
    echoerr "The available space is less than 100G, please replace the larger disk and try again! \n"
	echoerr "可用空间不足100G，请更换更大的磁盘后重试! \n"
fi