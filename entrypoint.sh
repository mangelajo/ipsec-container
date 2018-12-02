set -x
sysctl -w net.ipv4.ip_forward=1
cp /configuration/* /etc
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
sleep 10
ipsec auto --add mytunnel

#ExecStop=/usr/libexec/ipsec/whack --shutdown
#ExecStopPost=/sbin/ip xfrm policy flush
#ExecStopPost=/sbin/ip xfrm state flush
#ExecStopPost=/usr/sbin/ipsec --stopnflog
#ExecReload=/usr/libexec/ipsec/whack --listen
