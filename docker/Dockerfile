#
# This is an experimental Dockerfile that will create a onetwopunch container. 
# It hasn't been extensively tested, and there are likely things that won't work. 
# 

FROM phusion/baseimage
MAINTAINER superkojiman

# Install nmap and dependencies to build unicornscan
RUN apt-get update
RUN apt-get -y install \
    nmap \
    build-essential \
    flex \
    bison \
    git \
    wget

# Clone and build unicornscan from GitHub
RUN git clone https://github.com/dneufeld/unicornscan.git
RUN cd unicornscan && ./configure CFLAGS=-D_GNU_SOURCE && make && make install

# Install nmap
RUN wget --no-check-certificate https://raw.githubusercontent.com/superkojiman/onetwopunch/master/onetwopunch.sh -O /usr/local/bin/onetwopunch.sh
RUN chmod 755 /usr/local/bin/onetwopunch.sh

# Clean up
RUN apt-get -y purge \
    build-essential \
    git \
    wget
RUN apt-get -y autoremove

# Set entry point and default command
ENTRYPOINT ["/usr/local/bin/onetwopunch.sh"]
CMD ["-h"]
