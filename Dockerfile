FROM centos:latest
RUN yum install -y iproute iputils tcpdump libreswan which policycoreutils sysvinit-tools ethtool conntrack-tools
RUN yum install -y epel-release
RUN yum install -y iperf
#RUN yum install -y gcc automake autoconf
#RUN curl -L https://github.com/HewlettPackard/netperf/archive/netperf-2.7.0.tar.gz > /tmp/netperf.tar.gz
#RUN cd tmp && tar xvfz netperf.tar.gz && cd netperf-netperf-2.7.0 && ./configure && make install -j4 

RUN ipsec initnss --nssdir /etc/ipsec.d
COPY ./scripts/* /
CMD /run.sh
