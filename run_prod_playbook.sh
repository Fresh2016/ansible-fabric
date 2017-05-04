#!/bin/bash

OPTS=${OPTS:='-C'}
if [[ $1 ]]; then
    OPTS=$1
fi

case ${OPTS} in
    -vvv)
        ansible-playbook $OPTS -i inventories/prod/hosts prod.yml
        ;;
    -C)
        ansible-playbook $OPTS -i inventories/prod/hosts prod.yml
        ;;
    -p|-P)
        printf "\n\n\n<<<running prod_prepare.yml>>>\n\n\n"
        ansible-playbook -i inventories/prod/hosts prod_prepare.yml
        printf "\n\n\n<<<running prod.yml>>>\n\n\n"
        ansible-playbook -i inventories/prod/hosts prod.yml
        ;;
    -d|-D)
        ansible-playbook -i inventories/prod/hosts prod.yml
        ;;
    *)
        echo "Only 1 options accept: -vvv, -C, -p|-P, -d|-D"
        echo "    - vvv,    verbose output"
        echo "    - C,      dry run, check only, DEFAULT choice"
        echo "    - p|-P,   run prod_prepare.yml before running prod.yml"
        echo "    - d|-D,   ONLY run prod.yml"
        ;;
esac
