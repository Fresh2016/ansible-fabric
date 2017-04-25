#!/bin/bash

if [[ "$1" == "-vvv"  ]]; then
   OPS=$1
fi
if [[ "$1" == "-C" ]]; then
   OPS=$1
fi
ansible-playbook $OPS -i inventories/prod/hosts prod.yml
