Scripts that build and launch two docker containers with
an ipsec tunnel (encapsulated in a vxlan tunnel) between
them.

Usage:

A number (~60) kernel modules are required on the host. The easiest way to install
these is by installing libreswan and then starting and stopping it:

```ipsec setup start && ipsec setup stop```

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
