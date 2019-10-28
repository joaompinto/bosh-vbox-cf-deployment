#!/bin/bash
. scripts/yaml.sh
create_variables etc/config.yaml
echo $BOSH_RELEASE