#!/bin/bash
set -x

####
#  0) Housekeeping variables
####
CWD=$(pwd)


####
#   1) Install the packages required to perform Stack, Condor and Pegasus
#      installations.
####
#   1.1) EPEL and Powertools are needed because of Pegasus dependencies, even
#        though it makes the installation much longer.
sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
sudo dnf config-manager --set-enabled powertools

sudo yum update -y
sudo yum install -y curl patch git wget diffutils java
git clone -b packer https://github.com/DinoBektesevic/autobuilder.git


####
#   2) Install HTCondor for CentOS 8
####
wget https://research.cs.wisc.edu/htcondor/yum/RPM-GPG-KEY-HTCondor
sudo rpm --import RPM-GPG-KEY-HTCondor

sudo curl --output /etc/yum.repos.d/htcondor-stable-rhel8.repo \
     https://research.cs.wisc.edu/htcondor/yum/repo.d/htcondor-stable-rhel8.repo

sudo yum install -y condor

#   2.1) Fix Condor's SELinux conflicts and start it to create default configs.
sudo chmod 755 /var/log
sudo systemctl start condor

#   2.2 ) condor-annex-ec2 service is only supposed to be run on machines *which*
#         condor_annex adds to the pool. But we need the package on head as well
#         because it is designed to detect instance parameters at instance start
#         and we do not use long-lived head nodes. The reason why it won't hang
#         at boot-up on master is that we replace the bootup script with a custom
#         one (see 3.1). This also creates default config files, which are
#         then deleted (see 3.6).
sudo yum install -y condor-annex-ec2
sudo systemctl start condor-annex-ec2


####
#   3) Configure instance as HTCondor head node
####
#   3.1) Replace default Condor configuration files and fix condor-annex-ec2 script
cd $CWD

sudo cp ~/autobuilder/configs/condor_head_config /etc/condor/config.d/local
sudo cp ~/autobuilder/configs/condor_annex_ec2 /usr/libexec/condor/condor-annex-ec2

#   3.2) Give Condor programatic access to your cloud account
#        (TODO: see how to avoid by setting up IAMs in Terraform or similar)
mkdir -p ~/.condor
echo $AWS_SECRET_KEY > ~/.condor/privateKeyFile
echo $AWS_ACCESS_KEY > ~/.condor/publicKeyFile
sudo chmod 600 ~/.condor/*KeyFile

#   3.3) Configure a Condor Pool Password.
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

#   3.4) Configure Condor Annex
echo "SEC_PASSWORD_FILE=/home/centos/.condor/condor_pool_password" > ~/.condor/user_config
echo "ANNEX_DEFAULT_AWS_REGION=${AWS_REGION}" >> ~/.condor/user_config
sudo chown $USER ~/.condor/user_config

#   3.5) Set up an HTCondor S3 Transfer Plugin
sudo cp ~/autobuilder/configs/s3.sh /usr/libexec/condor/s3.sh
sudo chmod 755 /usr/libexec/condor/s3.sh
sudo cp ~/autobuilder/configs/10_s3 /etc/condor/config.d/10-s3

#   3.6) By now it should be safe to remove the default condor-annex-ec2 config.
sudo rm /etc/condor/config.d/50ec2.config

#   3.7) Restart Condor to reload config values. Run annex configurator.
sudo systemctl enable condor
sudo systemctl restart condor

condor_annex -aws-region $AWS_REGION -setup
condor_annex -check-setup

####
#   4) Install Pegasus.
#      This must occur after Condor installation since Condor is a dependency
####
wget -q https://download.pegasus.isi.edu/wms/download/rhel/8/x86_64/pegasus-5.0.0-1.el8.x86_64.rpm
sudo yum localinstall -y pegasus-5.0.0-1.el8.x86_64.rpm


####
#   5) Install the stack with newinstall.sh method
#      This is best done first so that Pegasus and HTCondor can be installed within the
#      miniconda env of the stack.
####
mkdir -p lsst_stack
cd lsst_stack

#   5.1) TODO: Update link to use master once the problem with env0.2.1 goes away
curl -OL https://raw.githubusercontent.com/lsst/lsst/w.2021.04/scripts/newinstall.sh
bash ~/lsst_stack/newinstall.sh -bct

source ~/lsst_stack/loadLSST.bash
eups distrib install -t w_latest lsst_distrib


####
#   6) Cleanup
####
cd $CWD

mkdir -p .install
mv -r autobuilder RPM-GPG-KEY-HTCondor pegasus-5.0.0-1.el8.x86_64.rpm -t .install/

echo "source ~/lsst_stack/loadLSST.bash" >> ~/.bashrc
echo "setup lsst_distrib" >> ~/.bashrc
echo "python ~/.install/autobuilder/auth/setUpCredentials.py" >> ~/.bashrc
