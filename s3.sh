#!/bin/sh

if [ "$1" = "-classad" ]
then
    echo 'PluginVersion = "0.1"'
    echo 'PluginType = "FileTransfer"'
    echo 'SupportedMethods = "s3"'
    exit 0
fi

source=$1
dest=$2

exec aws s3 cp ${source} ${dest}
