####
#  0) Housekeeping variables
####
CWD=$(pwd)
SECRET_ACCESS_KEY=$1
SECRET_ACCESS_KEY_ID=$2


####
#  1) Update the base OS
####
sudo yum update - y
sudo yum install -y yum-utils

echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections


####
#   2) Install the packages required to perform Stack, Condor and Pegasus installations.
####
sudo yum install -y curl patch git emacs vim wget gnupg awscli


####
#   3) Install the stack with newinstall.sh method
#      This is best done first so that Pegasus and HTCondor can be installed within the
#      miniconda env of the stack.
####
mkdir -p lsst_stack
cd lsst_stack

curl -OL https://raw.githubusercontent.com/lsst/lsst/master/scripts/newinstall.sh
bash newinstall.sh -bct

source loadLSST.bash

eups distrib install -t w_latest lsst_distrib


####
#   4) Install HTCondor - for now, probably best to be its own script or function
#      later on as installation differs between different versions of OSs.
####
cd ~
wget https://research.cs.wisc.edu/htcondor/yum/RPM-GPG-KEY-HTCondor
sudo rpm --import RPM-GPG-KEY-HTCondor

cd /etc/yum.repos.d
sudo wget https://research.cs.wisc.edu/htcondor/yum/repo.d/htcondor-stable-rhel8.repo

sudo yum install condor

sudo systemctl start condor
sudo systemctl enable condor

#  4.1)  Install condor-annex 0
#           Unsure how condor-annex installations work on el8
sudo yum install condor-annex-ec2


####
#   5) Configure instance as HTCondor head node - probably best to be a separate script.
#      Good for testing for now.
####
# 5.1) Configure a Condor Pool Password.
sudo condor_store_cred -c add -f `condor_config_val SEC_PASSWORD_FILE`

sudo chmod 600 /etc/condor/condor_pool_password
sudo chown root /etc/condor/condor_pool_password

mkdir -p ~/.condor
sudo cp /etc/condor/condor_pool_password ~/.condor/
sudo chmod 600 ~/.condor/condor_pool_password
sudo chown $USER ~/.condor/condor_pool_password

echo "SEC_PASSWORD_FILE=/home/$USER/.condor/condor_pool_password" > ~/.condor/user_config
echo "ANNEX_DEFAULT_AWS_REGION=us-east-2" >> ~/.condor/user_config

sudo chown $USER ~/.condor/user_config

# 5.2) Replace default Condor configuration files with head node ones.
cd $CWD

sudo cp condor_head_node_config /etc/condor/config.d/local
sudo cp condor-annex-ec2 /usr/libexec/condor/condor-annex-ec2

# 5.3) Give Condor programatic access to your cloud account
echo $SECRET_ACCESS_KEY > ~/.condor/privateKeyFile
echo $SECRET_ACCESS_KEY_ID > ~/.condor/publicKeyFile
sudo chmod 600 ~/.condor/*KeyFile



