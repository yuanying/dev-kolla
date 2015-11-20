#!/bin/bash

registry=operator.local
registry_port=4000

gpasswd -a $USER docker

cp ~/.ssh/authorized_keys ~root/.ssh/authorized_keys

install_docker() {
    echo "Installing Docker"
    apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
    echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" > /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y  docker-engine=1.8.2*
    sed -i -r "s,^[# ]*DOCKER_OPTS=.+$,DOCKER_OPTS=\"--insecure-registry $registry:$registry_port\"," /etc/default/docker
}

install_python_deps() {
    echo "Installing Python"
    # Python
    apt-get install -y python-setuptools python-dev libffi-dev libssl-dev
    easy_install pip
    pip install --upgrade pip virtualenv virtualenvwrapper
    pip install docker-py
}

install_ntp() {
    echo "Installing NTP"
    # NTP
    apt-get install -y ntp
}

install_docker
install_ntp
install_python_deps
