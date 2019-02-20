#!/bin/bash

set -x

VXLAN_OVERHEAD=50
IPSEC_OVERHEAD=56
IP_TCP_OVERHEAD=40

eth0_mtu=$(cat /sys/class/net/eth0/mtu)

sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.rp_filter=0

if [[ "x$UDP_BASE_PORT" != "x" ]]; then
   STATEFULSET_REPLICA=$(hostname | grep -Eo '[0-9]+$')
   UDP_PORT=$((UDP_BASE_PORT + STATEFULSET_REPLICA))
fi


if [[ "$SIDE" == "left" ]]; then
   local_overlay_ip=$LEFT_OVERLAY_IP
   srcport1=$((UDP_PORT + 30))
   srcport2=$((UDP_PORT + 40))
   dst_ip=169.254.1.2
else
   local_overlay_ip=$RIGHT_OVERLAY_IP
   srcport1=$((UDP_PORT + 10))
   srcport2=$((UDP_PORT + 20))
   dst_ip=169.254.1.1
fi

# CLEANUP conntrack for our UDP port before starting
# this is only useful on the host (some hostPort issue)
# conntrack -L -p udp | grep $UDP_PORT |  sed 's/=/ /g' | awk '{system("conntrack -D -s "$5" -d "$7" -p "$1" --sport="$9" --dport="$11)}'

# SETUP VXLAN TUNNEL
ip link add name vxlan42 type vxlan id 42 udpcsum remote $REMOTE_IP dstport $UDP_PORT
# random srcports # srcport $srcport1 $srcport2
ip link set dev vxlan42 mtu $((eth0_mtu - VXLAN_OVERHEAD))
ip addr add $local_overlay_ip/24 dev vxlan42
ip link set up vxlan42

# otherwise ipsec on top of VXLAN packets land ethernet with the wrong checksum, don't know why
ethtool -K eth0 tx-checksum-ip-generic off

if [[ "$IPSEC_ENABLED" == "yes" ]]; then

    if [[ "$SIDE" == "left" ]]; then
       echo $LEFT_OVERLAY_IP $RIGHT_OVERLAY_IP : PSK \"$PSK\" > /etc/ipsec.secrets
    else
       echo $RIGHT_OVERLAY_IP $LEFT_OVERLAY_IP : PSK \"$PSK\" > /etc/ipsec.secrets
    fi

# WRITE IPSEC CONFIG
    cat <<EOF > /etc/ipsec.conf
config setup
        virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12,%v4:25.0.0.0/8,%v4:100.64.0.0/10,%v6:fd00::/8,%v6:fe80::/10
        protostack=netkey

conn mytunnel
    auto=add
    nat-ikev1-method=none
    authby=secret
    phase2alg=aes_gcm-null
    left=$LEFT_OVERLAY_IP
    right=$RIGHT_OVERLAY_IP
    leftsubnet=0.0.0.0/0
    rightsubnet=0.0.0.0/0
    mark=5/0xffffffff
    vti-interface=vti01
    vti-routing=no
    #mtu=$((eth0_mtu - VXLAN_OVERHEAD - IPSEC_OVERHEAD)) # let's not use mtu because makes libreswan insert routes
    #leftvti=169.254.1.1/30
    #rightvti=169.254.1.2/30
    #leftupdown=/updown.sh
    #rightupdown=/updown.sh
EOF

    # Check configuration file
    /usr/libexec/ipsec/addconn --config /etc/ipsec.conf --checkconfig
    # Check for kernel modules
    /usr/libexec/ipsec/_stackmanager start
    # Check for nss database status and migration
    /usr/sbin/ipsec --checknss
    # Check for nflog setup
    /usr/sbin/ipsec --checknflog
    # Start the actual IKE daemon
    /usr/libexec/ipsec/pluto --leak-detective --config /etc/ipsec.conf #--nofork
    sleep 5
    ipsec auto --add mytunnel
fi # IPSEC_ENABLED == yes

# redirect local ports 100:30000 back and forth

for proto in udp tcp; do

   iptables -t nat -A PREROUTING -p $proto -i eth0 -m multiport \
            --dports 100:30000 \
            -j DNAT --to-destination $dst_ip
   iptables -A FORWARD -p $proto -d $dst_ip -m multiport \
            --dports 100:30000 \
            -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
done

iptables -t nat -A POSTROUTING -j MASQUERADE

