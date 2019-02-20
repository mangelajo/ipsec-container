#!/bin/bash

if [[ "$SIDE" == "left" ]]; then
   dst_ip=169.254.1.2
else
   dst_ip=169.254.1.1
fi

# if we are using ipsec, make sure that the ipsec tunnel
# is properly established

if [[ "$IPSEC_ENABLED" == "yes" ]]; then

    ip a show dev vti01 | grep 169.254.1 || exit 1

fi

ping -W 2 -c 1 $dst_ip

exit $?
