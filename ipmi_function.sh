#!/bin/sh
function usage()
{
    
    echo """
    ipmi_function version 1.01  Copyright (C) duyt(2021-05-26), capitalonline
    2021-05-26 version 1.01: Huawei Taishan Server
    USAGE: $0 [OPTIONS] < add_bmc_user | submit_onetime | vnc_control | bios_update  |
          | idrac_update | vnc_config | mail_alarm | snmp_alarm | performance_config |
          | boot_set | numa_config | pxe_config | alarm_config |boot_config | get_sn |
          | single_sn | get_mac | get_all_mac | config_raid | power_status | 
          | change_timezone | power_off | power_on | hardreset | delete_bmc_user > <password>
    
    Available OPTIONS:
    
      --ipaddr       <ipaddr>   ip.
      --ip_file      <ip_file>   ip list.
      --username     <username>   BMC admin user name
      --userpassword <userpassword>   BMC admin password
      --boot_type    <boot_type>   BIOS boot type Bios Uefi
      --flag_type    <flag_type>   valid flag type   
            none        : No override
            force_pxe   : Force PXE boot
            force_disk  : Force boot from default Hard-drive
            force_safe  : Force boot from default Hard-drive, request Safe Mode
            force_diag  : Force boot from Diagnostic Partition
            force_cdrom : Force boot from CD/DVD
            force_bios  : Force boot into BIOS Setup
      -h, --help      Show the help message.

      if error occurs, please check username & password & hostIP & syntax
    
    compatible bios version including 2.2.11 | 2.5.4
    compatible ibmc version including 3.34.34.34 | 4.10.10.10
    compatible nics type including 4 nics | 4 nics + 2 sub-nics"""
    exit 1
}


function parse_options()
{
    args=$(getopt -o h -l ip_file:,raid_type:,pxe_device:,disk_list:,ipaddr:,username:,userpassword:,boot_type:,file_path:,update_file:,flag_type:,vnc_password:,is_restart:,help -- "$@")

    if [[ $? -ne 0 ]];then
        usage >&2
    fi

    eval set -- "${args}"

    while true
    do
        case $1 in
            --flag_type)
                flag_type=$2
                shift 2
                ;;
		    --boot_type)
                boot_type=$2
                shift 2
                ;;
            --userpassword)
                userpassword=$2
                shift 2
                ;;
		    --username)
                username=$2
                shift 2
                ;;
            --ipaddr)
                ipaddr=$2
                shift 2
                ;;
			--is_restart)
				is_restart=$2
				shift 2
				;;
            --ip_file)
                ip_file=$2
                shift 2
                ;;
	    	--vnc_password)
	        	vnc_password=$2
	        	shift 2
	        	;;
	    	--update_file)
	        	update_file=$2
	        	shift 2
	        	;;
			--file_path)
				file_path=$2
				shift 2
				;;
	    	--raid_type)
				raid_type=$2
				shift 2
				;;
	    	--pxe_device)
                pxe_device=$2
                shift 2
                ;;
	    	--disk_list)
				disk_list=$2
				shift 2
				;;
            -h|--help)
                usage
                ;;
            --)
                shift
                break
                ;;
            *)
                usage
                ;;
        esac
    done
    
    if [[ $# -ne 3 ]]; then
        usage
    fi
    action=$1
    name=$2
    password=$3
}


function is_valid_action()
{
    action=$1
    valid_action=(add_bmc_user vnc_control bios_update idrac_update vnc_config mail_alarm submit_onetime snmp_alarm performance_config boot_set numa_config pxe_config alarm_config boot_config get_sn single_sn get_mac get_all_mac get_pxe_mac config_raid power_status power_off power_on change_timezone hardreset delete_bmc_user)
    for val in ${valid_action[@]}; do
        if [[ "${val}" == "${action}" ]]; then
            return 0
        fi
    done
    return 1
}

parse_options $@

is_valid_action ${action} || echo "invalid action"

path=`dirname $0`

Product_Name=`ipmitool -U $name -P $password -H $ipaddr -I lanplus  fru  |grep "Product Manufacturer" |awk '{print  $4}' | sed -n '1p'`

if [[ $Product_Name == '' ]]; then
        #/opt/dell/srvadmin/sbin/racadm -r $ipaddr -u $name  -p $password set iDRAC.IPMILan.Enable Enabled
        echo "IPMIservice may have an error, please check"
        #Product_Name=`ipmitool -U $name -P $password -H $ipaddr -I lanplus  fru  |grep "Product Manufacturer" |awk '{print  $4}' | sed -n '1p'`
fi

ipmitool -U $name -P $password -H $ipaddr -I lanplus chassis power status 1>/dev/null 2>&1

if [[ $? != 0 ]]; then
	echo "username or password not correct error"
	exit 1
fi
case "${Product_Name}" in
    DELL)
        source $path/dell.sh ;;

    Inspur)
        source $path/inspur.sh ;;

    Lenovo)
        source $path/lenovo.sh ;;

    Supermicro)
        source $path/supermicro.sh ;;

    Huawei)
        source $path/huawei.sh ;;

    *)
        echo "Unknown Action:${action}!"
	usage
        ;;
esac

case "${action}" in
    add_bmc_user)
	    add_bmc_user $ipaddr $name $password $username $userpassword
        ;;
    vnc_config)
        vnc_config $ipaddr $name $password $vnc_password
        ;;
    bios_update)
        bios_update $ipaddr $name $password $update_file $is_restart $file_path
    	;;
	idrac_update)
		idrac_update $ipaddr $name $password $update_file $file_path
		;;
	mail_alarm)
        mail_alarm $ipaddr $name $password
        ;;
    snmp_alarm)
        snmp_alarm $ipaddr $name $password
        ;;
    performance_config)
        performance_config $ipaddr $name $password
        ;;
    boot_set)
        boot_set $ipaddr $name $password $boot_type
        ;;
    numa_config )
        numa_config $ipaddr $name $password
        ;;
    pxe_config )
        pxe_config $ipaddr $name $password $pxe_device
        ;;
    alarm_config)
        alarm_config $ipaddr $name $password
        ;;
    submit_onetime)
    	submit_onetime $ipaddr $name $password $pxe_device
        ;;
    vnc_control)
    	vnc_control $ipaddr $name $password
        ;;
    boot_config)
        boot_config $ipaddr $name $password $flag_type
        ;;
    get_sn)
        get_sn $ipaddr $name $password
        ;;
    single_sn)
        single_sn $ipaddr $name $password
        ;;
    get_mac )
        get_mac $ipaddr $name $password
        ;;
    get_all_mac )
        get_all_mac $ipaddr $name $password
        ;;
    get_pxe_mac )
        get_pxe_mac $ipaddr $name $password
        ;;
    config_raid)
        config_raid $ipaddr $name $password $raid_type $disk_list
        ;;
    power_status)
        power_status $ipaddr $name $password 
        ;;
    power_off) 
        power_off $ipaddr $name $password 
        ;;
    power_on) 
        power_on $ipaddr $name $password 
        ;;
    change_timezone)
        change_timezone $ipaddr $name $password
        ;;
    hardreset)
        hardreset $ipaddr $name $password 
        ;;
    delete_bmc_user)
        delete_bmc_user $ipaddr $name $password $username
        ;;
    *)
        echo "Unknown Action:${action}!"
        usage
        ;;
esac

