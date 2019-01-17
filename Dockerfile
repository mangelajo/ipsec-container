FROM centos:latest
RUN yum install -y iproute iputils tcpdump libreswan which policycoreutils sysvinit-tools ethtool
RUN yum install -y epel-release
RUN yum install -y iperf
RUN ipsec initnss --nssdir /etc/ipsec.d
COPY ./scripts/* /
CMD /run.sh
