#!/bin/bash
set -x

BUILD_TYPE=$1
build_type="None"
case $BUILD_TYPE in
    "Worker")
        build_type="worker"
        ;;
    "WORKER")
        build_type="worker"
        ;;
    "worker")
        build_type="worker"
        ;;
    "Head")
        build_type="head"
        ;;
    "HEAD")
        build_type="head"
        ;;
    "head")
        build_type="head"
        ;;
esac

CWD=$(pwd)

# 1) Install all required packages.
. autobuilder/scripts/baseInstaller.sh

# 2) Run desired HTCondor configurator
if [ "$build_type" = "worker"]; then
    . autobuilder/scripts/workerConfigurator.sh
else
    . autobuilder/scripts/headConfigurator.sh
fi

# 3) Add the S3 HTCondor plugin.
. autobuilder/scripts/s3PluginInstaller.sh

#  4) Restart Condor to reload config values.
sudo systemctl restart condor
sudo systemctl start condor-annex-ec2
sudo systemctl enable condor-annex-ec2


# 5) Cleanup
cd $CWD
mkdir -p .install
mv RPM-GPG-KEY-HTCondor pegasus-5.0.0-1.el8.x86_64.rpm -t .install/
mv -nr autobuilder -t .install/

