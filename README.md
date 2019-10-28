# Deploy BOSH and CloudFoundry into VirtualBox


## Requirements
- Linux system with 16GB+ RAM
- VirtualBox
- Internet connectivity

## Install

```bash
# At the end of the deployment you will get instructions
# on how to login into your CF environment.
scripts/deploy.sh
```

## Deploy the "Stratos web interface

git clone https://github.com/cloudfoundry-incubator/stratos /tmp/stratos
cd /tmp/stratos
git checkout tags/stable -b stable
npm install
npm run prebuild-ui
cf push