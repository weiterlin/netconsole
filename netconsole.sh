#!/system/bin/sh
function CheckMacAddr() 
{
    if [ -z $1 ]
    then
        return 1
    fi
    if [ $# -eq 1 ]
    then
        echo $1 | busybox egrep -c "^[0-9]*:[0-9a-fA-F]{2}(:[0-9a-fA-F]{2}){5}$" 
        return $?
    fi
    return 1;
}

CheckIPAddr()
{
    if [ -z $1 ]
    then
        return 1
    fi
    echo $1 | grep "^[0-9]\{1,3\}\.\([0-9]\{1,3\}\.\)\{2\}[0-9]\{1,3\}$"
    #IP地址必须为全数字
    if [ $? -ne 0 ]
    then
        return 1
    fi
    ipaddr=$1
    a=`echo $ipaddr| busybox awk -F . '{print $1}'`   #以"."分隔，取出每个列的值
    b=`echo $ipaddr| busybox awk -F . '{print $2}'`
    c=`echo $ipaddr| busybox awk -F . '{print $3}'`
    d=`echo $ipaddr| busybox awk -F . '{print $4}'`
    for num in $a $b $c $d
    do
        if [ $num -gt 255 ] || [ $num -lt 0 ]     #每个数值必须在0-255之间
        then
            return 1
        fi
    done
    return 0
}

CheckIPPort()
{
    if [ -z $1 ]
    then
        return 1
    fi
    if [ $1 -ge 65536 ] || [ $1 -le 1024 ]
    then
        return 1
    fi
    return 0
}

#example
#setprop sys.remote_port 6666
#setprop sys.remote_ip 172.16.6.111
ifname="eth0"

remote_port=`getprop sys.remote_port`

CheckIPPort $remote_port
if [ $? -ne 0 ]
then
    echo "remote_port=$remote_port is error"
    return 1
fi
echo "remote_port=$remote_port"

local_port=$remote_port

remote_ip=`getprop sys.remote_ip`
CheckIPAddr $remote_ip
if [ $? -ne 0 ]
then
    echo "remote_ip=$remote_ip is error"
    return 1
fi
echo "remote_ip=$remote_ip"

echo "arping -f -w 1 -I $ifname $remote_ip"
remote_mac=`arping -f -w 1 -I $ifname $remote_ip`
remote_mac=`echo ${remote_mac#*\[}`
remote_mac=`echo ${remote_mac%%\]*}`
if CheckMacAddr $remote_mac
then

    gateway_ip=`busybox route -n | grep eth0 | grep UG | busybox awk '{print $2}'`
    CheckIPAddr $gateway_ip
    if [ $? -ne 0 ]
    then
        echo "gateway_ip=$gateway_ip is error"
        return 1
    fi
    echo "arping -f -w 1 -I $ifname $gateway_ip"
    remote_mac=`arping -f -w 1 -I $ifname $gateway_ip`
    remote_mac=`echo ${remote_mac#*\[}`
    remote_mac=`echo ${remote_mac%%\]*}`
    if CheckMacAddr $remote_mac
    then
        echo "remote_mac=$remote_mac is error"
    fi
fi
echo "remote_mac=$remote_mac"


local_ip=`toolbox ifconfig eth0`
local_ip=`echo ${local_ip#*ip }`
local_ip=`echo ${local_ip%% mask*}`
if [ -z $local_ip ]
then
    echo "local_ip=$local_ip is error"
    return 1
fi

local_mac=`cat /sys/class/net/$ifname/address`
if CheckMacAddr $remote_mac
then
    echo "local_mac=$local_mac is error"
    return 1;
fi
echo "local_mac=$local_mac"


if [ -d /sys/kernel/config/netconsole ]
then
    if [ ! -d /sys/kernel/config/netconsole/target ]
    then
        mkdir /sys/kernel/config/netconsole/target
        if [ $? -ne 0 ]
        then
            echo "{mkdir /sys/kernel/config/netconsole/target} failed"
            return 1
        fi
    fi
else
    busybox mount none -t configfs /sys/kernel/config
    if [ $? -ne 0 ]
    then
        echo "{busybox mount none -t configfs /sys/kernel/config} failed"
        return 1
    fi

    mkdir /sys/kernel/config/netconsole/target
    if [ $? -ne 0 ]
    then
        echo "{mkdir /sys/kernel/config/netconsole/target} failed"
        return 1
    fi
fi

echo 0 > /sys/kernel/config/netconsole/target/enabled
echo $ifname > /sys/kernel/config/netconsole/target/dev_name
echo $local_ip > /sys/kernel/config/netconsole/target/local_ip
echo $local_port > /sys/kernel/config/netconsole/target/local_port
echo $remote_ip > /sys/kernel/config/netconsole/target/remote_ip
echo $remote_port > /sys/kernel/config/netconsole/target/remote_port
echo $remote_mac > /sys/kernel/config/netconsole/target/remote_mac
echo 1 > /sys/kernel/config/netconsole/target/enabled
echo 15 15 1 15 > /proc/sys/kernel/printk
logcat -c
logcat -f /dev/kmsg 
