Scripts that build and lauch two docker containers with
an ipsec tunnel (encapsulated in a vxlan tunnel) between
them.

Usage:
1. See the vars file for the variables that need to be set
2. to build, say ./build
3. launch the right side by calling ./run right
4. launch the left side by calling ./run left

If you wish to configure routing on each side follow these
steps (note these are for the "left" side, just s/left/right
for the right side)
1. create a file called ./left/routes.sh
2. chmod +x that file ;-)
3. add "ip route" commands to that file...
4. ...where if you want traffic to go into the tunnel the "action" is dev vti01
