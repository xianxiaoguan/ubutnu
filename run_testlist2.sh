#!/bin/bash
#set -x      
######################################################################
# Copyright (c) 2018 IriStar Corporation.  All rights reserved.
######################################################################
#
# File: run_testlist2.sh
#   A tool to parse and run user configured test list
#
# Revision History: 
# v0.1 (2018/04/12)  
#   *Initial version
#

VERSION="v0.1 - 2018-APR-12"
if [ $UID -ne 0 ]; then
    echo "Please run this script as root or use 'sudo'!"
    exit 1
fi

PP=$$
MPN=$RANDOM-$PP.tmp
TMP_DIR=.tmp

[ ! -d "$TMP_DIR" ] && mkdir $TMP_DIR

LOG_NAME_ITEMS=$TMP_DIR/_logname_items-$MPN
> $LOG_NAME_ITEMS

SSH_USR=ubuntu
SSH_PSW=minisirzkzn

LOG_DIR=log
SYS_LOCK=/var/lock/run_testlist.lock

trap "on_exit" EXIT

on_exit()
{
    rm -rf $SYS_LOCK
    rm -rf $TMP_DIR/*-$PP.tmp
    [ -z "$(ls $TMP_DIR)" ] && rmdir $TMP_DIR
}

format_echo()
{
    [ $# -lt 2 ] && echo $1 || echo -e "\e[$1m$2\e[0m"
}

print_pass()
{
    format_echo 42 "                                           "
    format_echo 42 " #######      ####      ######     ######  "
    format_echo 42 " ########    ######    ########   ######## "
    format_echo 42 " ##    ##   ##    ##   ##     #   ##     # "
    format_echo 42 " ##    ##   ##    ##    ###        ###     "
    format_echo 42 " ########   ########     ####       ####   "
    format_echo 42 " #######    ########       ###        ###  "
    format_echo 42 " ##         ##    ##   #     ##   #     ## "
    format_echo 42 " ##         ##    ##   ########   ######## "
    format_echo 42 " ##         ##    ##    ######     ######  "
    format_echo 42 "                                           "
}

print_fail()
{
    format_echo 41 "                                           "
    format_echo 41 " #######      ####     ########   ###      "
    format_echo 41 " #######     ######    ########   ###      "
    format_echo 41 " ##         ##    ##      ##      ###      "
    format_echo 41 " ##         ##    ##      ##      ###      "
    format_echo 41 " #######    ########      ##      ###      "
    format_echo 41 " #######    ########      ##      ###      "
    format_echo 41 " ##         ##    ##      ##      ###      "
    format_echo 41 " ##         ##    ##   ########   ######## "
    format_echo 41 " ##         ##    ##   ########   ######## "
    format_echo 41 "                                           "
}



wait_pid_timeout()
{
    if [ $# -lt 2 ]; then
        echo "Usage: check_pid_timeout pid to_sec"
        return 1
    fi
    pid=$1
    to_sec=$2

    sta_time=$(date +%s)
    to_flag=0
    while ps -p $pid &>/dev/null; do
        sleep 0.1
        cur_time=$(date +%s)
        ((run_time=cur_time-sta_time))
        if [ "$run_time" -gt "$to_sec" ]; then
            kill $pid
            to_flag=1
            break
        fi
    done
    wait $pid 2>/dev/null
    ret=$?
    [ "$to_flag" = 1 ] && ret=124
    return $ret
}



check_ssh_conn()
{
    to_sec=$1

    echo "Check SSH connection..."
    sta_time=$(date +%s)
    while :; do
        echo y | plink -pw $SSH_PSW $SSH_USR@$DEV_IP "exit"
        [ $? -eq 0 ] && break
        echo "Not ready yet, will re-try in 5 seconds"
        sleep 5
        cur_time=$(date +%s)
        ((run_time=cur_time-sta_time))
        [ "$run_time" -gt "$to_sec" ] && return 124
    done
    echo "SSH connection ready!"
}

phidget_on()
{
    if [ $# -lt 1 ]; then
        echo "PHIDGET_POWER_PORT/PHIDGET_SN not configured!"
        return 1
    fi
    if [ $# -lt 2 ]; then
        sn=-1
        port=$1
    else
        sn=$1
        port=$2
    fi
    ./phidget_control.py $sn $port 1    
}

phidget_off()
{
    if [ $# -lt 1 ]; then
        echo "PHIDGET_POWER_PORT/PHIDGET_SN not configured!"
        return 1
    fi
    if [ $# -lt 2 ]; then
        sn=-1
        port=$1
    else
        sn=$1
        port=$2
    fi
    ./phidget_control.py $sn $port 0
}

mmi_run()
{
    cmd_line=$1
    to_sec=$2
    cmd_type=$(echo $cmd_line | awk '{print $1}')
    cmd=$(echo ${cmd_line#$cmd_type})
    case "$cmd_type" in
        SLEEP) sec=$((to_sec-1))
               echo "Sleep $to_sec seconds..."
               sleep $sec;;
        TESTBOX_POWER_ON) phidget_on $PHIDGET_SN $PHIDGET_POWER_PORT;;
        TESTBOX_POWER_OFF) phidget_off $PHIDGET_SN $PHIDGET_POWER_PORT;;
        INIT_SSH_CONNECTION) check_ssh_conn $to_sec;; 
        *) echo "Unsupported MMI command: $cmd!"
             exit 1;;
    esac     
}

lnx_run()
{
    cmd_line=$1
    to_sec=${2:-0}
    path=$(echo $cmd_line | awk '{print $1}')
    cmds=$(echo ${cmd_line#$path})

    path_var="LNX_$path"
    host_path=${!path_var}
    if [ -z "$host_path" ]; then
        echo "Linux host path '$path_var' not configured!"
        return 1
    fi
    if [ ! -d "$host_path" ]; then
        echo "Linux host path '$host_path' not found!"
        return 1
    fi
    echo "cd $host_path"
    cd $host_path
    echo $cmds
    timeout $to_sec bash -c "$cmds"   
}



dev_run()
{
    cmd=$1
    to_sec=$2
    # ???!!! 
    #timeout $to_sec plink -pw $SSH_PSW $SSH_USR@$DEV_IP "$cmd"   
    # !!!??? 
    echo $cmd
    plink -pw $SSH_PSW $SSH_USR@$DEV_IP "$cmd" &
    pid=$!
    sta_time=$(date +%s)
    while ps -p $pid &>/dev/null; do
        sleep 0.2

        if [ -n "$pass_str" ]; then
            if [ -n "$(tail -5 $test_log | grep "$pass_str")" ]; then
                ret=0
                sleep 0.2
                kill $pid 2>/dev/null
                wait $pid 2>/dev/null
                return 0
            fi
        fi

        if [ -n "$fail_str" ]; then
            if [ -n "$(tail -5 $test_log | grep "$fail_str")" ]; then
                ret=1
                sleep 0.2
                kill $pid 2>/dev/null
                wait $pid 2>/dev/null
                return 1 
            fi
        fi
        cur_time=$(date +%s)
        ((run_time=cur_time-sta_time))
        if [ "$run_time" -gt "$to_sec" ]; then
            kill $pid 2>/dev/null
            wait $pid 2>/dev/null
            return 124
        fi
    done
    wait $pid 2>/dev/null
}

# ITEM=["item name", "command type", "command", "pass string", "fail string", "golden time", "timeout seconds"]
parse_item()
{
    item_line=$1
    # echo $item_line

    item_name=$(echo $item_line | awk -F\" '{print $2}')
    cmd_type=$(echo $item_line | awk -F\" '{print $4}')
    cmd=$(echo $item_line | awk -F\" '{print $6}')
    pass_str=$(echo $item_line | awk -F\" '{print $8}')
    fail_str=$(echo $item_line | awk -F\" '{print $10}')
    to_sec=$(echo $item_line | awk -F\" '{print $14}')

    echo "#------------------------------------------# | Run Test Item $item_name"

    test_log=$TMP_DIR/_test-$MPN
    >$test_log
    case "$cmd_type" in
      DEV) test_handler=dev_run;;
      LNX) test_handler=lnx_run;;
      MMI) test_handler=mmi_run;;
        *) echo "Unsupported command type: $cmd_type!"
             exit 1;;
    esac
    #eval "$test_handler \"$cmd\" $to_sec 2>&1 | tee $test_log"
    $test_handler "$cmd" $to_sec 2>&1 | tee $test_log
    ret=$?

    ##################################
    ## Result determine logic A: 
    ##   when "pass_str" not specified, take shell return code into consideration
    ##
    #if [ "$ret" -ne 124 ] && [ -n "$pass_str" ]; then
    #    if [ -n "$(tail -5 $test_log | grep "$pass_str")" ]; then
    #        ret=0
    #    else
    #        ret=1
    #    fi
    #fi
    ##################################

    #################################
    # Result determine logic B:
    #   when "pass_str" not specified, always PASS
    #
    if [ -n "$pass_str" ]; then
        if [ "$ret" -ne 124 ]; then
            if [ -n "$(tail -5 $test_log | grep "$pass_str")" ]; then
                ret=0
            else
                ret=1
            fi
        fi
    else     
        ret=0
    fi
    #################################

    if [ "$ret" -eq 0 ]; then
        msg='PASS'
    elif [ "$ret" -eq 124 ]; then
        msg='TIMEOUT'
    else
        msg='FAIL'
    fi

    echo "#------------------------------------------# | $item_name Test $msg!"
    echo "#------------------------------------------# | End of Test Item $item_name"
    echo

    # Fetch configured "LOG_NAME_ITEM" and add it to log filename
    if [ "$ret" -eq 0 ]; then
        for log_name_item in "${LOG_NAME_ITEM[@]}"; do
           item=$(echo $log_name_item | awk -F: '{print $1}')
            pattern=$(echo ${log_name_item#$item})
            pattern=$(echo ${pattern#:})
            if [ "$item_name" = "$item" ]; then
                match=$(grep -o "$pattern" $test_log)
                if [ -n "$match" ]; then
                    echo $match >>$LOG_NAME_ITEMS
                fi
            fi
        done
    fi
    rm $test_log

    return $ret
}


clean_on_fail()
{
    echo "Clean on fail..."
    if [ "$MODE" = "DEBUG" ]; then
       echo "no any clean up action..."
       echo "board should still on failure condition..."
    else   
       phidget_off $PHIDGET_SN $PHIDGET_POWER_PORT &>/dev/null
     fi
}

run_testlist()
{
    testlist_file=$1
    testlist_lines=$(sed -n '/^\[TESTLIST\]/,${//!p}' $testlist_file)

    start_time=$(date +%s)
    echo
    echo "RUN TESTLIST Version: $VERSION"
    echo "Test started @ $(date +'%F %T' -d @$start_time)"

    bak_IFS=$IFS
    IFS=$'\n'
    for line in $testlist_lines; do
        IFS=$bak_IFS
        line=$(echo $line | sed 's/\r//g')
        [ -z "$line" ] || [ -n "$(echo $line | grep '^#')" ] && continue
        list_type=$(echo $line | awk -F= '{print $1}')
        case "$list_type" in
          SEG) parse_seg "$line";;
          ITEM) parse_item "$line";;
          *) echo "Unsupported list type: $list_type!"
             exit 1;;
        esac
        ret=$?
        [ $ret -ne 0 ] && break
    done
    if [ $ret -eq 0 ]; then
        print_pass
    else
        print_fail
        echo
        clean_on_fail
    fi

    end_time=$(date +%s)
    ((cycle_time=end_time-start_time))
    echo
    echo "Test ended @ $(date +'%F %T' -d @$end_time)"
    echo "The cycle time: $cycle_time seconds."

    return $ret
}

check_cfg()
{
    if [ ! -f "$TEST_LIST" ]; then
        echo "Testlist file '$TEST_LIST' not found!"
        exit 1
    fi
    if [ -z "$DEV_IP" ]; then
        echo "DEV_IP not configured!"
        exit 1
    fi
}

########## Main Routines ##########

#run_dir=$(pwd)
#cd $(dirname $0)

[ ! -d $LOG_DIR ] && mkdir $LOG_DIR

#if [ $# -lt 1 ]; then
#    echo "Please specify the configuration file!"
#    exit 1
#fi
cfg_file=${1:-setup.cfg}
#[ "${cfg_file:0:1}" = / ] || cfg_file="$run_dir/$cfg_file"
if [ ! -f "$cfg_file" ]; then
    echo "Configuration file '$cfg_file' not found!"
    exit 1
fi
. $cfg_file
check_cfg

set -o pipefail
log_file=$LOG_DIR/TBD_NOSN-$(date +%Y%m%d-%H:%M)
for (i=0,i<=20,i++);do	
	run_testlist $TEST_LIST 2>&1 | tee $log_file
	printf ("当前的运行次数为：%s	\n") $i | tee $log_file
	if [ $? -ne 0 ];then
		break
	fi
done
ret=$?
[ $ret -eq 0 ] && result=PASS || result=FAIL
sed -i 's/[\x8\r]//g' $log_file
sn=($(cat $LOG_NAME_ITEMS))
rm $LOG_NAME_ITEMS
sn=${sn[@]}
new_log_file=$log_file
if [ -n "$sn" ]; then
    sn=${sn/ /_}
    new_log_file=${new_log_file/NOSN/$sn}
fi
new_log_file=${new_log_file/TBD/$result}
new_log_file=$new_log_file.log
mv $log_file $new_log_file
echo "Log: $new_log_file"
echo

exit $ret
