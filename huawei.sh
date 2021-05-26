#!/bin/sh

log_file="/var/log/cdsstack/huawei_log"
date_info=`date`

function remote()
{
hostname=$1
user=$2
passwd=$3
get='ipmcget -d passwordcomplexity'
set='ipmcset -d passwordcomplexity'
expect<<-EOF
spawn ssh ${user}@${hostname}
expect "*password:" { send "${passwd}\r" }
expect "*->*"
send "${get}\r"
expect "*enable" { send "${set} -v disabled\r" }
expect "*continue*" { send "Y\r" }
expect eof
EOF
}

function timezone()
{
hostname=$1
user=$2
passwd=$3
tz=$4
get='ipmcget -d time'
set='ipmcset -d timezone'
expect<<-EOF
spawn ssh ${user}@${hostname}
expect "*password:" { send "${passwd}\r" }
expect "*->*"
send "${set} -v ${tz}\r"
expect "*successfully*" { send "${get}\r" }
expect eof
EOF
}

function ibmc_get_mac()
{
hostname=$1
user=$2
passwd=$3
get='ipmcget -d macaddr'
expect<<-EOF
spawn ssh ${user}@${hostname}
expect "*password:" { send "${passwd}\r" }
expect "*->*"
send "${get}\r"
expect "*NIC"
send "exit\r"
expect eof
EOF
} 

function add_bmc_user()
{
    echo "==== add bmc user test ==== " >> $log_file
    a=`remote $1 $2 $3 | grep disabled`
    if [[ $? == 0 ]];then
        echo "diable password complexity success" >> $log_file
        return 1
    else
        echo "diable password complexity failed" >> $log_file
        return 0
    fi
    ipmitool_commd="ipmitool -U $2 -P $3 -H $1 -I lanplus"
        $ipmitool_commd user list | grep "$4"
    if [[ $? == 0 ]]; then
        a=`$ipmitool_commd user list | grep "$4" | awk '{print $1}'`
        $ipmitool_commd  user set password $a $5
        if [[ $? == 0 ]]; then
            echo "host ip: $1  date: $date_info  result: change password success" >> $log_file
        else
            echo "host ip: $1  date: $date_info  result: change password error" >> $log_file
        fi
    else
        for((i=2;i<17;i++));
        do
            $ipmitool_commd user list | sed -n "2,17"p | sed -n "$i"p | grep "NO ACCESS"
            if [[ $? == 0 ]]; then
                $ipmitool_commd  user set name $i $4
                $ipmitool_commd  user set password $i $5
                $ipmitool_commd  user priv $i 4 1
                $ipmitool_commd sol payload enable 1 $i
                $ipmitool_commd  channel  setaccess 1 $i ipmi=on
                $ipmitool_commd  user enable $i
                $ipmitool_commd  user list |grep "$4"
                if [[ $? == 0 ]]; then
                    echo "host ip: $1  date: $date_info  result: add bmc username:$4  password:$5 success" >> $log_file
                else
                    echo "host ip: $1  date: $data_info  result: add bmc username:$4  password:$5 error" >> $log_file
                fi
            fi
        done
    fi
    echo "host ip: $1  date: $data_info  result: add bmc username:$4  password:$5 error user list is full" >> $log_file
    return 1
}

function alarm_config()
{
    echo "==== alarm config test ==== " >> $log_file
    echo "Huawei does not currently support ipmi alarm config" >> $log_file
}

function boot_set()
{
    echo "==== boot set test ==== " >> $log_file
    #ipmitool_commd="ipmitool -U $2 -P $3 -H $1 -I lanplus"
    #boot_set_status=`$ipmitool_commd chassis bootdev cdrom options=efiboot | awk '{print $5}'`
    echo "host ip: $1  date: $date_info  result: boot mode only support UEFI" >> $log_file

}

function boot_config()
{
    echo "==== boot config test ==== " >> $log_file
    ipmitool_commd="ipmitool -U $2 -P $3 -H $1 -I lanplus"
    bootparam=`$ipmitool_commd  chassis bootparam set bootflag force_pxe | awk '{print $5}'`
    echo "host ip: $1  date: $date_info  result: bootparam set to $bootparam" >> $log_file
}
function vnc_config()
{
    echo "==== vnc config test ==== " >> $log_file
    ipmitool_commd="ipmitool -U $2 -P $3 -H $1 -I lanplus"
    sol_stat=`$ipmitool_commd sol info | grep Enabled | awk '{print $3}'`
    while [[ "$sol_stat" == "true" ]] || [[ "$sol_stat" == "false" ]]
    do
        if [[ "$sol_stat" == "true" ]]; then
            echo "host ip: $1  date: $date_info  result: sol is enabled" >> $log_file
            break;
        elif [[ "$sol_stat" == "false" ]]; then
            $ipmitool_commd sol payload enable 1 2
            if [[ "$sol_stat" == "true" ]]; then
                echo "host ip: $1  date: $date_info  result: sol is enabled" >> $log_file
            else
                echo "host ip: $1  date: $date_info  result: sol is disabled" >> $log_file 
            
            fi
        fi
    done
    $ipmitool_commd sol info | grep  115.2
    if [[ $? == 0 ]]; then
                echo "host ip: $1  date: $date_info  result: set sol bit rate 115.2  success" >> $log_file
                break;
        else
                $ipmitool_commd sol set volatile-bit-rate 115.2
                $ipmitool_commd sol set non-volatile-bit-rate 115.2
                $ipmitool_commd sol info |grep  115.2
                if [[ $? == 0 ]]; then
                    echo "host ip: $1  date: $date_info  result: set sol bit rate 115.2  success" >> $log_file
                else
                    echo "host ip: $1  date: $date_info  result: set sol bit rate 115.2  error" >> $log_file
                fi
        fi
}

function vnc_control()
{
    echo "==== vnc control test ==== " >> $log_file
    ipmitool_commd="ipmitool -U $2 -P $3 -H $1 -I lanplus"
    result=`$ipmitool_commd sol looptest 1 2>&1 | sed -n 2p`
    if [[ $result =~ 'operational' ]]; then
        echo "host ip: $1  date: $date_info  result: able to log via sol" >> $log_file
    else
        echo "host ip: $1  date: $date_info  result: unable to log via sol" >> $log_file
    fi
}



function ibmc_get_version()
{
hostname=$1
user=$2
passwd=$3
get='ipmcget -d version'
expect<<-EOF
spawn ssh ${user}@${hostname}
expect "*password:" { send "${passwd}\r" }
expect "*->*"
send "${get}\r"
expect eof
EOF
}

function get_sn()
{
    echo "==== get BIOS,BMC version and mainboard SN test ==== " >> $log_file
    ipmitool_commd="ipmitool -U $2 -P $3 -H $1 -I lanplus"
    #bios_ver=`ibmc_get_version $1 $2 $3 | grep "Version" | grep "BIOS"`
    #bmc_ver=`ibmc_get_version $1 $2 $3 | grep "Version" | grep "iBMC"`
    get_bios_ver=`$ipmitool_commd raw 0x30 0x90 0x08 0x00 0x06 0x00 0x10`
    bmc_ver=`$ipmitool_commd mc info | grep -w "Firmware Revision" | awk '{print $4}'`
    mb_sn=`$ipmitool_commd fru | grep -w "Product Serial" | head -1 | awk '{print $4}'`
    bios_ver=''
    for i in $get_bios_ver
    do
        char=`printf "\\x$i"`
        bios_ver="$bios_ver""$char";
    done
    echo """host ip:$1  date: $date_info  result: 
            BIOS Version: $bios_ver
            iBMC Version: $bmc_ver
            Mainboard SN: $mb_sn""" >> $log_file
}

function single_sn()
{
    echo "==== get mainboard SN test ==== " >> $log_file
    ipmitool_commd="ipmitool -U $2 -P $3 -H $1 -I lanplus"
    mb_sn=`$ipmitool_commd fru | grep -w "Product Serial" | head -1 | awk '{print $4}'`
    echo "host ip:$1  date: $date_info  result: Mainboard SN: $mb_sn" >> $log_file
}

function get_mac()
{
    echo "==== get system mac test ==== " >> $log_file
    ipmitool_commd="ipmitool -U $2 -P $3 -H $1 -I lanplus"
    dev_mac=`ipmitool -U Administrator -P Admin@9000 -H 10.128.205.74 -I lanplus raw 0x30 0x90 0x45 0x02 00 00 | tr ' ' ':' | awk '{print substr($1,2)}'`
    echo "host ip: $1  date: $date_info  result: device mac: $dev_mac" >> $log_file
}


function get_all_mac()
{
    echo "==== get all mac test ==== " >> $log_file
    ibmc_get_mac $1 $2 $3 | grep NIC
    if [[ $? == 0 ]];then
        echo "host ip: $1  date: $date_info  result: get all mac success" >> $log_file
        ibmc_get_mac $1 $2 $3 | grep NIC | while read line;do
        po=`echo $line | awk '{print $5}'`
        mac_addr=`echo $line | awk '{print $7}'`
        echo "result info: " $po $mac_addr >> $log_file
        done
    else
        echo "host ip: $1  date: $date_info  result: get all mac failed" >> $log_file
    fi
}


function get_pxe_mac()
{
    echo "==== get all pxe mac test ==== " >> $log_file
    ibmc_get_mac $1 $2 $3 | grep NIC
    if [[ $? == 0 ]];then
        echo "host ip: $1  date: $date_info  result: get all pxe mac success" >> $log_file
        ibmc_get_mac $1 $2 $3 | grep NIC | while read line;do
        echo "read line: " $line
        po=`echo $line | awk '{print $5}'`
        mac_addr=`echo $line | awk '{print $7}'`
        echo "result info: " $po $mac_addr >> $log_file
        done
    else
        echo "host ip: $1  date: $date_info  result: get all pxe mac failed" >> $log_file
    fi
}


function performance_config()
{
    echo "==== CPU performance config ==== " >> $log_file
    echo "Huawei does not currently support ipmi set CPU performance config" >> $log_file
}

function mail_alarm()
{
    echo "==== mail alarm test ==== " >> $log_file
    echo "Huawei does not currently support ipmi set mail alarm" >> $log_file
}

function numa_config()
{
    echo "==== numa config test ==== " >> $log_file
    echo "Huawei does not currently support ipmi numa config" >> $log_file
}


function power_status()
{
    echo "==== power status test ==== " >> $log_file
    ipmitool_commd="ipmitool -U $2 -P $3 -H $1 -I lanplus"
    status=`$ipmitool_commd  power status |awk '{print $4}'`
    echo "host ip: $1  date: $date_info  result: power status: $status" >> $log_file
}

function power_off()
{
    echo "==== power off test ==== " >> $log_file
    ipmitool_commd="ipmitool -U $2 -P $3 -H $1 -I lanplus"
    status=`$ipmitool_commd  power status |awk '{print $4}'`
    if [[ "$status" == "off" ]];then
        echo "host ip: $1  date: $date_info  result: already powered off" >> $log_file
        result=1
    elif [[ "$status" == "on" ]];then
        result=0
    else
        result=2
    fi

    case "$result" in
        0)
            $ipmitool_commd  power off
            if [[ $? != 0 ]];then
                echo "host ip: $1  date: $date_info  result: power off error" >> $log_file
                return 0
            fi
            let retry=1
            let totle_number=1
            while [ 1 ]
            do
                status=`$ipmitool_commd  power status |awk '{print $4}'`
                sleep 1
                if [[ "$status" ==  "off" ]];then
                    echo "host ip: $1  date: $date_info  result: power off success" >> $log_file
                    break;
                fi

                if [[ $retry == 10 ]];then
                    $ipmitool_commd  power off
                    let retry=1
                fi

                let retry++
                let totle_number++
                if [[ $totle_number == 200 ]];then
                    echo "host ip: $1  date: $date_info  result: power off error" >> $log_file
                    break
                fi
            done
            ;;
        1)
            break
            ;;
        2)
            echo "host ip: $1  date: $date_info  result: some error occured" >> $log_file
            ;;
    esac
}

function power_on()
{
    echo "==== power on test ==== " >> $log_file
    ipmitool_commd="ipmitool -U $2 -P $3 -H $1 -I lanplus"
    status=`$ipmitool_commd  power status |awk '{print $4}'`
    if [[ "$status" == "off" ]];then
        result=0
    elif [[ "$status" == "on" ]];then
        echo "host ip: $1  date: $date_info  result: already powered on" >> $log_file
        result=1
    else
        result=2
    fi

    case "$result" in
        0)
            $ipmitool_commd  power on
            if [[ $? != 0 ]];then
                echo "host ip: $1  date: $date_info  result: power on error" >> $log_file
                return 0
            fi
            let retry=1
            let totle_number=1
            while [ 1 ]
            do
                status=`$ipmitool_commd  power status |awk '{print $4}'`
                sleep 1
                if [[ "$status" ==  "on" ]];then
                    echo "host ip: $1  date: $date_info  result: power on success" >> $log_file
                    break;
                fi

                if [[ $retry == 10 ]];then
                    $ipmitool_commd  power on
                    let retry=1
                fi

                let retry++
                let totle_number++
                if [[ $totle_number == 200 ]];then
                    echo "host ip: $1  date: $date_info  result: power on error" >> $log_file
                    break
                fi
            done
            ;;
        1)
            break
            ;;
        2)
            echo "host ip: $1  date: $date_info  result: some error occured" >> $log_file
            ;;
    esac
}

function hardreset()
{
    echo "==== hard reset test ==== " >> $log_file
    ipmitool_commd="ipmitool -U $2 -P $3 -H $1 -I lanplus"
    $ipmitool_commd  power reset
    if [[ $? != 0 ]];then
        echo "host ip: $1  date: $date_info  result: power reset error" >> $log_file
    else
        echo "host ip: $1  date: $date_info  result: power reset success" >> $log_file
    fi
}

function change_timezone()
{
    echo "==== change timezone test ==== " >> $log_file
    if [[ $4 == '' ]]; then
        default='Asia/Shanghai'
    else
        default=$4
    fi
    timezone $1 $2 $3 $default | grep $default

    if [[ $? == 0 ]]; then
        echo "host ip: $1  date: $date_info  result: change timezone success" >> $log_file
    else
        echo "host ip: $1  date: $date_info  result: change timezone fail" >> $log_file
    fi
}


function delete_bmc_user()
{
    echo "==== delete bmc user test ==== " >> $log_file
    ipmitool_commd="ipmitool -U $2 -P $3 -H $1 -I lanplus"
    $ipmitool_commd user list | grep "$4"
    if [[ $? == 0 ]]; then
        user=`$ipmitool_commd user list | grep "$4" | awk '{print $2}'`
        l=`$ipmitool_commd user list | grep $user | awk '{print $1}'`
        while [[ $user != "" ]]
        do
            $ipmitool_commd  user set name $l ""
            sleep 1
            user=`$ipmitool_commd user list | grep "$4" | awk '{print $2}'`
            sleep 1
            $ipmitool_commd user list | grep "$4"
            if [[ $? != 0 ]]; then
                echo "host ip: $1  date: $date_info  result: user delete success" >> $log_file
                break;
            else
                echo "host ip: $1  date: $date_info  result: user delete fail" >> $log_file
            fi
        done
    else
        echo "host ip: $1  date: $date_info  result: no such user" >> $log_file
    fi
}
