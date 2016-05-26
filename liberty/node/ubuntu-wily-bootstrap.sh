#!/bin/bash

REGISTRY_HOST=operator.local
REGISTRY_PORT=4000

REGISTRY=${REGISTRY_HOST}:${REGISTRY_PORT}

cp ~/.ssh/authorized_keys ~root/.ssh/authorized_keys

# Install common packages and do some prepwork.
function prep_work {
    if [[ "$(systemctl is-enabled firewalld)" = "enabled" ]]; then
        systemctl stop firewalld
        systemctl disable firewalld
    fi

    # This removes the fqdn from /etc/hosts's 127.0.0.1. This name.local will
    # resolve to the public IP instead of localhost.
    sed -i -r "s/^(127\.0\.0\.1\s+)(.*) `hostname` (.+)/\1 \3/" /etc/hosts

    apt-get update
    apt-get install -y python-mysqldb python-dev build-essential libssl-dev libffi-dev libxml2-dev libxslt-dev
    easy_install pip

    pip install --upgrade docker-py
}

# Install and configure a quick&dirty docker daemon.
function install_docker {

    apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
    echo "deb https://apt.dockerproject.org/repo ubuntu-wily main" > /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y docker-engine
    sed -i -r "s,(ExecStart)=(.+),\1=/usr/bin/docker daemon --insecure-registry ${REGISTRY} --registry-mirror=http://${REGISTRY}|" /lib/systemd/system/docker.service

    systemctl daemon-reload
    systemctl enable docker
    systemctl start docker
}

prep_work
install_docker
