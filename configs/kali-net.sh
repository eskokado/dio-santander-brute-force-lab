#!/bin/bash
cid=$(nmcli -t -f DEVICE,UUID con show | grep eth0 | cut -d: -f2)
echo "CID=$cid"
nmcli con mod "$cid" ipv4.method manual ipv4.addresses 192.168.56.4/24 ipv4.gateway "" ipv4.dns ""
nmcli con down "$cid"
nmcli con up "$cid"
sleep 2
ip -br a show eth0
ip r
ping -c1 -W2 192.168.56.1
