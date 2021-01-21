import os
import time

import boto3
import botocore.session
from botocore.exceptions import ClientError
import click


def key_pair_exists(keyPairName):
    ec2 = boto3.resource('ec2')
    keysFilter = ec2.key_pairs.filter(KeyNames=[keyPairName, ])
    try:
        keys = [key for key in keysFilter]
    except ClientError:
        return False
    return True

def create_key_pair(saveDir=".", keyPairName="RubinAWS"):
    ec2 = boto3.resource('ec2')

    # confirm key-pair name is unique
    i = 1
    while key_pair_exists(keyPairName):
        keyPairName = f"{keyPairName}{i}"
        i += 1

    # create a new keypair
    keyPair = ec2.create_key_pair(KeyName=keyPairName)

    # write to a file with 600 permissions:
    keyFilePath = os.path.join(os.path.abspath(saveDir), f"{keyPairName}.pem")
    fd = os.open(keyFilePath, os.O_WRONLY | os.O_CREAT, 0o600)
    with open(fd, "w") as keyFile:
        keyFile.write(keyPair.key_material)

    return keyFilePath


def security_group_exists(secGroupName):
    ec2 = boto3.resource('ec2')
    secGrpFilter = ec2.security_groups.filter(GroupNames=[secGroupName, ])
    try:
        secGroup = [secGrp for secGrp in secGrpFilter]
    except ClientError:
        return False
    return True


def create_security_group(secGroupName="RubinAWS0",
                          secGrpDescription="Default security group for Rubin AWS autobuilder.",
                          vpcId="default"):
    ec2 = boto3.resource('ec2')

    i = 1
    if security_group_exists(secGroupName):
        secGroupName = f"{secGroupName}{i}"
        i += 1

    if vpcId == "default":
        for vpc in list(ec2.vpcs.all()):
            if vpc.is_default:
                vpcId = vpc.vpc_id

    # create a new security group
    secGroup = ec2.create_security_group(GroupName=secGroupName,
                                         Description=secGrpDescription,
                                         VpcId=vpcId)

    while not security_group_exists(secGroup.group_name):
        time.sleep(5)

    click.echo(f"{secGroup.group_name} security group created with ID {secGroup.group_id} in VPC {vpcId}.")

    secGroup.authorize_ingress(IpProtocol="tcp", CidrIp="0.0.0.0/0",
                               FromPort=80, ToPort=80)
    secGroup.authorize_ingress(IpProtocol="tcp", CidrIp="0.0.0.0/0",
                               FromPort=22, ToPort=22)

    return secGroup.group_id


def create_master_instance(keyPairDir="~/.ssh/", keyPair="Dino_Bektesevic_lsstspark",
                           securityGroup="RubinAWS0"):
    ec2 = boto3.resource('ec2')

    if not key_pair_exists(keyPair):
        if click.confirm("Key pair does not exist. Create a key-pair {keyPair}?",
                         default=True):
            keyPair = create_key_pair(keyPairDir, keyPair)

    if not security_group_exists(securityGroup):
        if click.confirm("Security group does not exist. "
                         f"Create a new security group {securityGroup}?",
                         default=True):
            securityGroup = create_security_group(secGroupName=securityGroup)
    else:
        secGrpFilter = ec2.security_groups.filter(GroupNames=[secGroupName, ])
        securityGroup = [secGrp for secGrp in secGrpFilter][0]

    # create a new EC2 instance
    instanceType = "m5.2xlarge"
    instanceAmi = "ami-0155c31ea13d4abd2"
    instances = ec2.create_instances(
        BlockDeviceMappings=[
            {
                'DeviceName': '/dev/sda1',
                'Ebs': {
                    'DeleteOnTermination': True,
                    'VolumeSize': 100,
                    'VolumeType': 'gp2'
                },
            },
        ],
        ImageId=instanceAmi,
        InstanceType=instanceType,
        SecurityGroupIds = [securityGroup, ],
        MaxCount=1,
        MinCount=1,
        KeyName=f"{keyPair}"
    )
    instance = instances[0]

    click.echo(f"Launching {instanceType} instance from {instanceAmi}.\n"
    "This can take a couple of minutes.")
    instance.wait_until_running()
    click.echo(f"Instance {instance.id} running.")

    ## pull builder scripts from git and run them
    commands = ["git clone "]
    resp = ec2.send_command(
        DocumentName="AWS-RunShellScript",
        Parameters={'commands': commands},
        InstanceIds=instance_ids,
    )
    return resp


if __name__ == "__main__":
    create_master_instance()
