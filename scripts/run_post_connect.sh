set -x

while true
do
    ip tunnel | grep -q vti01 && break
    sleep 1
done

if [ -f /configuration/routes.sh ]
then
    /configuration/routes.sh
fi
