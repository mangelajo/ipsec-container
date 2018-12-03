set -x

sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.rp_filter=0

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
