Scripts that build a docker container for VXLAN+ipsec tunnels

Usage:

A number (~60) kernel modules are required on the host. The easiest
way to install these is by copying the provided modules conf file:

```bash
$ cp system/modules-load.d/ipsec.conf file to /etc/modules-load.d/ipsec.conf
```

If you don't want to wait until next reboot you can run in your worker nodes:

```bash
for x in $(cat system/modules-load.d/ipsec.conf); do sudo modprobe $x; done
```
# Usage in kubernetes integration

Inside the kubernetes directory there are a sets of yaml files that you can
use to build and test kubernetes to kubernetes IPSEC tunnels.

The "deployment" yamls have a set of variables, including REMOTE_IP that needs
to point to the public IP exposing the remote cluster UDP port used for communication.

Imagine you have cluster A, with a public IP address 38.145.34.212 pointing to one
of it's nodes and UDP exposed on 30020-30030 for VXLAN communication, and cluster B, with
a public IP address 38.145.35.46 pointing to one of it's nodes, and same port.

## Labeling the nodes

First you must label the nodes to indentify the placement of the vpnPods,

```bash
$ export KUBECONFIG=~/.kube/clusterA-config
$ oc label nodes node1 extip=38.145.34.212
```

```bash
$ export KUBECONFIG=~/.kube/clusterB-config
$ oc label nodes node1 extip=38.145.35.46
```

Those labels will be used by the vpn pods to select the specific nodes they need
to sitting in (so the right IP/port will be pointed to them).

## Starting the vpn pod sides

### From clusterA to clusterB

NOTE: if you want to do a bare VXLAN connection (no IPSEC, please use the
-p IPSEC_ENABLED=no parameter on both sides.

```bash
$ export KUBECONFIG=~/.kube/clusterA-config

$ oc process -f vpnpod-template.yml -p REPLICA_ID=1 \
                                    -p SIDE=left \
                                    -p REMOTE_IP=38.145.35.46 \
                                    -p UDP_PORT=30020 \
                                    -p REMOTE_NAME=clusterb \
                                    -p EXTERNAL_IP=38.145.34.212 \
                        | oc create -f -

# Optional step
# if you want HA, you can create a 2nd replica of the tunnel with the next UDP port
# and the next replica ID
$ oc process -f vpnpod-template.yml -p REPLICA_ID=2 \
                                    -p SIDE=left \
                                    -p REMOTE_IP=38.145.35.46 \
                                    -p UDP_PORT=30021 \
                                    -p REMOTE_NAME=clusterb \
                                    -p EXTERNAL_IP=38.145.34.212 \
                        | oc create -f -

```

### From clusterB to clusterA

```bash
$ export KUBECONFIG=~/.kube/clusterB-config

$ oc process -f vpnpod-template.yml -p REPLICA_ID=1 \
                                    -p SIDE=right \
                                    -p REMOTE_IP=38.145.34.212 \
                                    -p UDP_PORT=30020 \
                                    -p REMOTE_NAME=clustera \
                                    -p EXTERNAL_IP=38.145.35.46 \
                        | oc create -f -

# Optional step
# if you want HA, you can create a 2nd replica of the tunnel with the next UDP port
# and the next replica ID

$ oc process -f vpnpod-template.yml -p REPLICA_ID=2 \
                                    -p SIDE=right \
                                    -p REMOTE_IP=38.145.34.212 \
                                    -p UDP_PORT=30021 \
                                    -p REMOTE_NAME=clustera \
                                    -p EXTERNAL_IP=38.145.35.46 \
                        | oc create -f -

```

## Checking status

```bash
$ export KUBECONFIG=~/.kube/clusterA-config
$ oc get pods | grep vpnpod
vpnpod-clusterb-left-1       1/1       Running   6          0d
vpnpod-clusterb-left-2       1/1       Running   6          0d

$ export KUBECONFIG=~/.kube/clusterB-config
$ oc get pods | grep vpnpod
vpnpod-clustera-right-1       1/1       Running   6          0d
vpnpod-clustera-right-2       1/1       Running   6          0d


# you can log into the vpn pods and see interfaces, addresses, etc...

$ oc rsh vpnpod-clustera-right-1
  ip l
  ip a

  ping 169.254.0.1 # left side (VXLAN level)
  ping 169.254.1.1 # left side (IPSEC level)

```

## Creating a service in cluster A that you want to expose to cluster B

```bash
$ export KUBECONFIG=~/.kube/clusterA-config
$ oc new-app -e MYSQL_ROOT_PASSWORD=1234root \
             -e MYSQL_USER=user \
             -e MYSQL_PASSWORD=pass \
             -e MYSQL_DATABASE=db \
             openshift/mysql-55-centos7

# manual step to funnel this service through port 100 in vti tunnel:

$ oc rsh vpnpod-clusterb-left-1
   iptables -t nat -A PREROUTING -p tcp -i vti01 --dport 100 -j DNAT --to-destination $(getent hosts mysql-55-centos7 | awk '{ print $1 }'):3306
   iptables -A FORWARD -m state -p tcp -d $(getent hosts mysql-55-centos7 | awk '{ print $1 }') --dport 3306 --state NEW,ESTABLISHED,RELATED -j ACCEPT
   iptables -t nat -A POSTROUTING -j MASQUERADE
   exit

$ oc rsh vpnpod-clusterb-left-2
   iptables -t nat -A PREROUTING -p tcp -i vti01 --dport 100 -j DNAT --to-destination $(getent hosts mysql-55-centos7 | awk '{ print $1 }'):3306
   iptables -A FORWARD -m state -p tcp -d $(getent hosts mysql-55-centos7 | awk '{ print $1 }') --dport 3306 --state NEW,ESTABLISHED,RELATED -j ACCEPT
   iptables -t nat -A POSTROUTING -j MASQUERADE
   exit
```

## Exposing such service in cluster B
```bash

$ export KUBECONFIG=~/.kube/clusterB-config
$ oc apply -f kubernetes/left/mysql-tunneled-left.yml
```

mysql-tunneled-left.yml looks like:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-55-centos7
  labels:
    app: mysql-55-centos7
spec:
  selector:
    vpnpod: to-clustera
  type: ClusterIP
  ports:
   - port: 3306
     targetPort: 100
     protocol: TCP
```

# Developing/testing the container

1. See the vars file for the variables that need to be set
2. to build, say ./build

You can test the containers by using the run script:

```bash
./run
```
The containers will be started in the background, you can log into
them by running:

```bash
sudo docker exec -ti left bash
sudo docker exec -ti right bash
```

Or you can check the logs by running
```bash
sudo docker logs left
sudo docker logs right
```


Note that the left side initiates the connection.

If you wish to configure routing on each side attach a volume
mounted on /configuration including the file "routes.sh"
1. chmod +x that file ;-)
2. add "ip route" commands to that file...
3. ...where if you want traffic to go into the tunnel the "action" is dev vti01

