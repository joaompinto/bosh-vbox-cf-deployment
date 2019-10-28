#!/bin/bash

set -e

kernel_type=$(uname -s|tr '[:upper:]' '[:lower:]')
BIN_DIR=$HOME/vbox-cf/bin
DEP_DIR=$HOME/vbox-cf/deployments
VAR_DIR=$HOME/vbox-cf/var

yaml2vars() {
    yaml_filename=$1
    var_txt=$(egrep -v "^#|^$" ${yaml_filename} | sed -e 's/:[^:\/\/]/="/g;s/$/"/g;s/ *=/=/g')
    echo "${var_txt}"
}

download_bosh_cli() {
    URL="https://github.com/cloudfoundry/bosh-cli/releases/download/v${BOSH_RELEASE}/bosh-cli-${BOSH_RELEASE}-${kernel_type}-amd64"
    mkdir -p "${BIN_DIR}"
    wget $URL -O $BIN_DIR/bosh.new.$$
    chmod +x $BIN_DIR/bosh.new.$$
    mv $BIN_DIR/bosh.new.$$ $BIN_DIR/bosh
    echo $BOSH_RELEASE
}

download_bosh_deployment(){
    mkdir -p ${DEP_DIR}/bosh
    URL="https://github.com/cloudfoundry/bosh-deployment/archive/${BOSH_DEPLOYMENT_VERSION}.tar.gz"
    wget $URL -O /tmp/$$.tar.gz
    tar --strip-components=1 -C ${DEP_DIR}/bosh -xvf /tmp/$$.tar.gz
}

download_cf_deployment(){
    mkdir -p ${DEP_DIR}/cf
    URL="https://github.com/cloudfoundry/cf-deployment/archive/v${CF_DEPLOYMENT_VERSION}.tar.gz"
    wget $URL -O /tmp/$$.tar.gz
    tar --strip-components=1 -C ${DEP_DIR}/cf -xvf /tmp/$$.tar.gz
}

eval $(yaml2vars etc/config.yaml)
[[ ! -x ${BIN_DIR}/bosh ]] && download_bosh_cli
[[ ! -d ${DEP_DIR}/bosh ]] && download_bosh_deployment
[[ ! -d ${DEP_DIR}/cf ]] && download_cf_deployment


${BIN_DIR}/bosh create-env ${DEP_DIR}/bosh/bosh.yml \
    --state ${VAR_DIR}/bosh_state.json  \
    -o ${DEP_DIR}/bosh/virtualbox/cpi.yml \
    -o ${DEP_DIR}/bosh/virtualbox/outbound-network.yml \
    -o ${DEP_DIR}/bosh/bosh-lite.yml \
    -o ${DEP_DIR}/bosh/bosh-lite-runc.yml \
    -o ${DEP_DIR}/bosh/uaa.yml \
    -o ${DEP_DIR}/bosh/credhub.yml \
    -o ${DEP_DIR}/bosh/jumpbox-user.yml \
    -v director_name=bosh-lite \
    -v internal_ip=192.168.50.6 \
    -v internal_gw=192.168.50.1 \
    -v internal_cidr=192.168.50.0/24 \
    -v outbound_network_name=NatNetwork \
    --vars-store ${VAR_DIR}/bosh-vars.yml

cat > $HOME/vbox-cf/env << _EOF_
export BOSH_ENVIRONMENT=192.168.50.6
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=$(${BIN_DIR}/bosh int ${VAR_DIR}/bosh-vars.yml --path /admin_password)
_EOF_
. $HOME/vbox-cf/env
${BIN_DIR}/bosh alias-env vbox -e 192.168.50.6 --ca-cert <(${BIN_DIR}/bosh int ${VAR_DIR}/bosh-vars.yml --path /director_ssl/ca)
${BIN_DIR}/bosh -n update-runtime-config ${DEP_DIR}/bosh/runtime-configs/dns.yml --name dns


${BIN_DIR}/bosh -n update-cloud-config ${DEP_DIR}/cf/iaas-support/bosh-lite/cloud-config.yml
STEMCELL_OS=$(${BIN_DIR}/bosh int ${DEP_DIR}/cf/cf-deployment.yml --path '/stemcells/alias=default/os')
STEMCELL_VERSION=$(${BIN_DIR}/bosh int ${DEP_DIR}/cf/cf-deployment.yml --path '/stemcells/alias=default/version')

${BIN_DIR}/bosh stemcells| grep -c bosh-warden || ${BIN_DIR}/bosh upload-stemcell "https://bosh.io/d/stemcells/bosh-warden-boshlite-${STEMCELL_OS}-go_agent?v=${STEMCELL_VERSION}"

${BIN_DIR}/bosh -n -d cf deploy ${DEP_DIR}/cf/cf-deployment.yml \
    -o ${DEP_DIR}/cf/operations/bosh-lite.yml \
    -o ${DEP_DIR}/cf/operations/use-compiled-releases.yml \
    -v system_domain=$SYSTEM_DOMAIN \
    --vars-store ${VAR_DIR}/cf-vars.yml


echo ""
echo "You can now login into your CF environment, using:"
echo ""
echo "  sudo ip route add 10.244.0.0/16 via 192.168.50.6 # Add route to the vbox vm"
echo "  cf login -a https://api.$SYSTEM_DOMAIN -u admin --skip-ssl-validation"
echo ""
echo "You can get the admin password by running:"
echo "  scripts/get-password.sh"
echo ""