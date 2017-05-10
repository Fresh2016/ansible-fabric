#!/bin/bash
echo    ">> This is a test script, doing nothing <<"
echo    "------------------------------------------"
echo -e "\n\n$(env | grep ^AMX)\n\n"
echo -e "------------------------------------------\n\n\n"

CNT=1
while [ ${CNT} -le ${AMX_ALERT_LEN} ]; do
    echo "  >> start to fix the ${CNT} alert ..."

    eval "LABEL_ACTION=\${AMX_ALERT_${CNT}_LABEL_action}"
    eval "LABEL_INSTANCE=\${AMX_ALERT_${CNT}_LABEL_instance}"
    eval "CONTAINER_NAME=\${AMX_ALERT_${CNT}_LABEL_name}"

    TGT_HOST=$(echo ${LABEL_INSTANCE} | cut -d ':' -f1)
    echo "     AMX_ALERT_${CNT} need action -- ${LABEL_ACTION}"
    echo "     AMX_ALERT_${CNT} is occur on ${TGT_HOST}"
    echo "     Restarting ${CONTAINER_NAME} on ${TGT_HOST}"

    echo "  >> finish to fix the ${CNT} alert ..."
    ((CNT+=1))
done

#
# -----------------------------------------------------------------------
#

#
# loop for all alerts
#      for each alert, get label_name     --> container instance name
#                          label_instance --> container host
#                          label_action   --> compair to some where store the previous action and time
#                      check connectivity with label_instance
#                      check container state
#                      execute recovery action --> reboot/restore??
#                      verify container state  --> update alert?? if failed to recover?? HOW and WHERE??

set_ssh_opts() {
    #
    # Func:  generate ssh options for ssh/scp connection
    # Usage: set_ssh_opts SSH_OPTS
    #        SSH_OPTS will be the return value from set_ssh_opts
    #
    local SSH_BASE_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=3"

    local KEYPAIR_FILE=${KEYPAIR_FILE:="/am-executor/scripts/id_rsa"}
    if [[ ! -e "${KEYPAIR_FILE}" ]]; then
        echo "ERROR: ${KEYPAIR_FILE} is not found!!! "
        exit 1
    fi

    local SSH_OPTS=${SSH_BASE_OPTS}" -i ${KEYPAIR_FILE}"

    eval "$1=\"${SSH_OPTS}\""
}

check_host_connectivity() {
    #
    # func:  check host connectivity via ssh
    # Usage: check_host_connectivity CONNECTIVITY "${SSH_OPTS}" "${TGT_HOST}"
    #        CONNECTIVITY will be the return value from check_host_connectivity
    #        "" around is required
    #
    local SSH_OPTS=$2
    local TGT_HOST=$3

    RET=`ssh ${SSH_OPTS} ${TGT_HOST} "echo connected" 2> /dev/null`

    if [[ $RET == "connected" ]]; then
        CONNECTIVITY="success"
    else
        CONNECTIVITY="failed"
    fi

    eval "$1=\"${CONNECTIVITY}\""
}

copy_and_run_on_host() {
    #
    # func:  copy and run shell script on target host
    # Usage: copy_and_run_on_host "${SSH_OPTS}" "${SCRIPT}" "${TGT_HOST}"
    #
    local SSH_OPTS=$1
    local SCRIPT=$2
    local TGT_HOST=$3

    scp ${SSH_OPTS} ${SCRIPT} ${TGT_HOST}:/tmp/${SCRIPT}
    ssh {SSH_OPTS} ${TGT_HOST} "chmod +x /tmp/${SCRIPT} && cd /tmp && nohup ./${SCRIPT} >${SCRIPT}.log 2>&1 &"
}

generate_recovery_script() {
    #
    # func:  generate recovery script for target docker instance on target host
    # Usage: generate_recovery_script "${SSH_OPTS}" "${SCRIPT}" "${TGT_HOST}"
    #
}

#
#---------------------------------------
#

#script on target
#    check docker daemon state
#    check container state
#    try to restart
#    verify container state
#    check /hfc-data/<container>
#    run /hfc-data/<container>/restore/run-xxx.sh
#    verify container state
#    set result


func script() {
    #!/bin/bash
    #
    # check status by check docker server version
    SERVER_VERSION=`docker version --format {{.Server.Version}} 2>/dev/null`
    if [[ ! ${SERVER_VERSION} ]]; then
        echo "ERROR: docker daemon is stopped !!!"
        echo "       Trying to restart docker daemon ..."
        RET=`systemctl start docker.service`

        if [[ ${RET} -eq 0 ]]; then
            echo "INFO:  docker daemon restarted ..."
            echo "       Trying to restart all docker instances ..."
            # get all instances not in running state
            docker ps -qa -f "status=exited" -f "status=dead" -f "status=paused"
        else
            echo "ERROR: docker daemon cannot started !!!"
            echo "       Exit recovery operation now ..."
            exit 1
        fi
    fi

}