FROM centos:latest
RUN mkdir -p /configuration
RUN yum install -y iproute iputils tcpdump libreswan which policycoreutils sysvinit-tools
RUN ipsec initnss --nssdir /etc/ipsec.d
COPY entrypoint.sh /
