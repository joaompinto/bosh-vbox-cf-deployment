#!/bin/sh
# This script will copy the cf admin password to the clipoard
BIN_DIR=$HOME/vbox-cf/bin
DEP_DIR=$HOME/vbox-cf/deployments
VAR_DIR=$HOME/vbox-cf/var

${BIN_DIR}/bosh int ${VAR_DIR}/cf-vars.yml --path /cf_admin_password | xclip -sel clip
echo "The CF Admin password is now available from your clipoard content"
