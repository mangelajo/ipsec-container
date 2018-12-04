set -x
/setup.sh
ipsec auto --up mytunnel
sleep 5

/run_post_connect.sh

while true
do
    ipsec whack --trafficstatus | grep -q '"mytunnel"' || exit
    sleep 5
done
