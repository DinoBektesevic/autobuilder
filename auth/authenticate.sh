#!/usr/bin/env bash

python3 setUpCredentials.py

export AWS_ACCESS_KEY_ID=`cat ~/.condor/publicKeyFile`
export AWS_SECRET_ACCESS_KEY=`cat ~/.condor/privateKeyFile`
