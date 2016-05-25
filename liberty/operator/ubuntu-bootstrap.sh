#!/bin/bash

KOLLA_PATH=$1

REGISTRY_HOST=operator.local
REGISTRY_PORT=4000

REGISTRY=${REGISTRY_HOST}:${REGISTRY_PORT}

function configure_kolla {
#     # Use local docker registry
#     sed -i -r "s,^[# ]*namespace *=.+$,namespace = ${REGISTRY}/lokolla," /etc/kolla/kolla-build.conf
#     sed -i -r "s,^[# ]*push *=.+$,push = True," /etc/kolla/kolla-build.conf
#     sed -i -r "s,^[# ]*docker_registry:.+$,docker_registry: \"${REGISTRY}\"," /etc/kolla/globals.yml
#     sed -i -r "s,^[# ]*docker_namespace:.+$,docker_namespace: \"lokolla\"," /etc/kolla/globals.yml
#     sed -i -r "s,^[# ]*docker_insecure_registry:.+$,docker_insecure_registry: \"True\"," /etc/kolla/globals.yml
#     # Set network interfaces
#     sed -i -r "s,^[# ]*network_interface:.+$,network_interface: \"eth0\"," /etc/kolla/globals.yml
#     sed -i -r "s,^[# ]*neutron_external_interface:.+$,neutron_external_interface: \"eth1\"," /etc/kolla/globals.yml
    echo "Skip configureing kolla"
}

# Configure the operator node and install some additional packages.
function configure_operator {
    apt-get install -y git mariadb-client selinux-utils

    pip install --upgrade "ansible<2" python-openstackclient python-neutronclient tox

    pip install ${KOLLA_PATH}

    # Set selinux to permissive
    if [[ "$(getenforce)" == "Enforcing" ]]; then
        sed -i -r "s,^SELINUX=.+$,SELINUX=permissive," /etc/selinux/config
        setenforce permissive
    fi

    tox -c ${KOLLA_PATH}/tox.ini -e genconfig
    cp -r ${KOLLA_PATH}/etc/kolla/ /etc/kolla
    ${KOLLA_PATH}/tools/generate_passwords.py
    mkdir -p /usr/share/kolla
    chown -R $USER: /etc/kolla /usr/share/kolla

    configure_kolla

    # Launch a local registry (and mirror) to speed up pulling images.
    if [[ ! $(docker ps -a -q -f name=registry) ]]; then
        docker run -d \
            --name registry \
            --restart=always \
            -p ${REGISTRY_PORT}:5000 \
            -e STANDALONE=True \
            -e MIRROR_SOURCE=https://registry-1.docker.io \
            -e MIRROR_SOURCE_INDEX=https://index.docker.io \
            -e STORAGE_PATH=/var/lib/registry \
            -v /data/host/registry-storage:/var/lib/registry \
            registry:2
    fi
}

configure_operator
