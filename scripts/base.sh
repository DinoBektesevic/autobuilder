#!/bin/bash
set -x

####
#  0) Housekeeping variables
####
CWD=$(pwd)


####
#   1) Install the packages required to perform Stack, Condor and Pegasus installations.
####
sudo yum update -y
sudo yum install -y curl patch git wget
git clone -b packer https://github.com/DinoBektesevic/autobuilder.git


####
#   2) Install HTCondor - for now, probably best to be its own script or function
#      later on as installation differs between different versions of OSs.
####
wget https://research.cs.wisc.edu/htcondor/yum/RPM-GPG-KEY-HTCondor
sudo rpm --import RPM-GPG-KEY-HTCondor

cd /etc/yum.repos.d
sudo wget https://research.cs.wisc.edu/htcondor/yum/repo.d/htcondor-stable-rhel8.repo

sudo yum install -y condor

#   2.1) Fix Condor's SELinux conflicts and start it to create default configs.
sudo chmod 755 /var/log
sudo systemctl enable condor
sudo systemctl start condor

#   2.1)  Install condor-annex 0
#           Unsure how condor-annex installations work on el8
sudo yum install -y condor-annex-ec2


####
#   3) Configure instance as HTCondor head node - probably best to be a separate script.
#      Good for testing for now.
####
#   3.1) Replace default Condor configuration files with head node ones.
cd $CWD

sudo cp ~/autobuilder/configs/condor_head_config /etc/condor/config.d/local
sudo cp ~/autobuilder/configs/condor_annex_ec2 /usr/libexec/condor/condor-annex-ec2

#   3.2) Give Condor programatic access to your cloud account
mkdir -p ~/.condor
echo $SECRET_ACCESS_KEY > ~/.condor/privateKeyFile
echo $SECRET_ACCESS_KEY_ID > ~/.condor/publicKeyFile
sudo chmod 600 ~/.condor/*KeyFile

#   3.4) Configure a Condor Pool Password.
#        Both Condor and Condor Annex need the condor pool password. But Condor needs it
#        to be securely owned by the root and Annex needs it securely owned by USER.
#        This must happen after head node configs have been detected by condor, since
#        that's where passwd file path is set.
random_passwd=`tr -cd '[:alnum:]' < /dev/urandom | fold -w30 | head -n1`
passwd_file_path=`condor_config_val SEC_PASSWORD_FILE`
sudo condor_store_cred add -f $passwd_file_path -p $random_passwd

sudo cp $passwd_file_path ~/.condor/

sudo chmod 600 $passwd_file_path ~/.condor/condor_pool_password
sudo chown root $passwd_file_path
sudo chown $USER ~/.condor/condor_pool_password

#   3.5) Configure Condor Annex
echo "SEC_PASSWORD_FILE=/home/centos/.condor/condor_pool_password" > ~/.condor/user_config
echo "ANNEX_DEFAULT_AWS_REGION=us-west-2" >> ~/.condor/user_config
sudo chown $USER ~/.condor/user_config

#   3.6) Set up an HTCondor S3 Transfer Plugin
sudo cp ~/autobuilder/configs/s3.sh /usr/libexec/condor/s3.sh
sudo chmod 755 /usr/libexec/condor/s3.sh
sudo cp ~/autobuilder/configs/10_s3 /etc/condor/config.d/10-s3

#   3.7) Follow the not-completely clear step from HTCondor manual.
sudo rm /etc/condor/config.d/50ec2.config

#   3.8) Restart Condor to reload config values.
sudo systemctl restart condor


####
#   4) Install the stack with newinstall.sh method
#      This is best done first so that Pegasus and HTCondor can be installed within the
#      miniconda env of the stack.
####
mkdir -p lsst_stack
cd lsst_stack

curl -OL https://raw.githubusercontent.com/lsst/lsst/master/scripts/newinstall.sh
bash ~/lsst_stack/newinstall.sh -bct

source ~/lsst_stack/loadLSST.bash
eups distrib install -t w_latest lsst_distrib

