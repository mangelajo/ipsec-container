FROM centos:latest
RUN yum install -y iproute iputils tcpdump libreswan which policycoreutils sysvinit-tools
RUN ipsec initnss --nssdir /etc/ipsec.d
COPY ./scripts/* /
CMD /run.sh
