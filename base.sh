sudo yum update - y
sudo yum install -y yum-utils

# install docker
sudo yum-config-manager --add-repo  https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io

# start docker service
sudo systemctl start docker


########################################
# Dockerfile?
########################################
FROM ubuntu
USER root
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# install stack prerequisites
RUN apt update
RUN apt upgrade -y
RUN apt install -y curl patch git

# install stack
RUN mkdir -p lsst_stack && cd lsst_stack
RUN curl -OL https://raw.githubusercontent.com/lsst/lsst/master/scripts/newinstall.sh
RUN bash newinstall.sh -bct

RUN source loadLSST.bash

RUN eups distrib install -t w_latest lsst_distrib


# install HTCondor
RUN cd ~
RUN apt install -y wget gnupg
RUN wget -qO - https://research.cs.wisc.edu/htcondor/ubuntu/HTCondor-Release.gpg.key | apt-key add -
