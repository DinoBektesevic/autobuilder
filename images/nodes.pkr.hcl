variable "aws_region" {
    type    = string
    default = "us-west-2"
}

variable "aws_access_key" {
    type    = string
    default = "${env("AWS_ACCESS_KEY_ID")}"
}

variable "aws_secret_key" {
    type    = string
    default = "${env("AWS_SECRET_ACCESS_KEY")}"
}

variable "instance_type" {
    type    = string
    default = "m5.2xlarge"
}

variable "volume_size" {
    type    = number
    default = 100
}

variable "base_ami_name" {
    type    = string
    default = "CentOS 8.3.2011 x86_64"
}

variable "aws_profile" {
    type    = string
    default = "${env("AWS_PROFILE")}"
}


source "amazon-ebs" "head" {
    profile = "$(var.aws_profile}"
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    instance_type = "${var.instance_type}"
    region = "${var.aws_region}"
    source_ami_filter {
        filters = {
            virtualization-type = "hvm"
            name = "${var.base_ami_name}"
            root-device-type = "ebs"
        }
        owners = [ "125523088429" ]
        most_recent = true
    }
    launch_block_device_mappings {
            device_name = "/dev/sda1"
            volume_size = "${var.volume_size}"
            volume_type = "gp2"
            delete_on_termination = true
    }
    ssh_username = "centos"
    ami_name = "packerTest-{{timestamp}}"
}


build {
    source "amazon-ebs.head" {
      name = "worker"
    }

    sources = ["source.amazon-ebs.head", ]

    provisioner "file" {
        source = "../scripts"
        destination = "/tmp"
    }
    provisioner "shell" {
        inline = [
          "chmod u+x /tmp/scripts/autobuilder.sh",
          "/tmp/scripts/autobuilder.sh ${source.name}"
        ]
    }
}
