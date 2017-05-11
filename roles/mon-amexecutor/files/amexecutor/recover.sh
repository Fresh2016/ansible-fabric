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

    tmp_script=`ssh ${SSH_OPTS} ${TGT_HOST} "mktemp" 2>/dev/null`
    scp ${SSH_OPTS} ${SCRIPT} ${TGT_HOST}:${tmp_script}
    ssh ${SSH_OPTS} ${TGT_HOST} "chmod +x ${tmp_script} && cd nohup bash ${tmp_script} >${tmp_script}.log 2>&1 &"
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
    # get args from stdin
    target_instance_id=$1
    #target_instance_name=$2
    #target_instance_image=$3

    get_timestamp() {
        printf "%.19s" "$(date +%Y%m%d.%H%M%S.%N)"
    }

    get_dockerd_version() {
        printf "`docker version --format {{.Server.Version}} 2>/dev/null`"
    }

    get_name_by_id(){
        local instance_id=$1
        printf "`docker ps -a -f id="${instance_id}" --format {{.Names}}`"
    }

    get_image_by_id(){
        local instance_id=$1
        printf "`docker ps -a -f id="${instance_id}" --format {{.Image}} | awk -F '/|-|:' '{print $2}'`"
    }

    get_stopped_instances(){
        printf "`docker ps -qa -f "status=exited" -f "status=dead" -f "status=paused"`"
    }

    is_instance_running() {
        local instance_id=$1
        printf "`docker ps -q -f id="${instance_id}"`"
    }

    get_backup_file_by_image() {
        #
        # check backup files from
        #              /var/lib/docker/dnsmasq-backup     for dnsmasq
        #              /var/lib/docker/hfc-backup         for fabric nodes
        #              /var/lib/docker/monitoring-backup  for monitoring nodes
        #
        local instance_name=$1
        local instance_image=$2
        local backup_dir

        case ${instance_image,,} in
            dnsmasq)
                backup_dir=/var/lib/docker/dnsmasq-backup
                ;;
            fabric)
                backup_dir=/var/lib/docker/hfc-backup
                ;;
            *)
                backup_dir=/var/lib/docker/monitoring-backup
                ;;
        esac

        printf "`ls ${backup_dir}/${instance_name}* 2>/dev/null | sort | tail -1`"
    }

    set_restore_file_from_backup_tgz() {
        #
        # backup_tgz should be tar.gz file with full path archived
        # target_dir should be /hfc-data/${instance_name}
        #
        local backup_tgz=$1
        local target_dir=$2

        local timestamp=`get_timestamp`
        # backup existing */restore file
        if [[ -e "${target_dir}" ]]; then
            mv -f ${target_dir} ${target_dir}.${timestamp}
        fi

        # replace with backup file
        temp_dir=$(mktemp -d)
        tar -zxf ${backup_tgz} -C ${temp_dir}

        # make sure /hfc-data exists, for some cases that the volume may not mounted to the host
        mkdir -p /hfc-data/
        mv -f ${temp_dir}/hfc-data/${target_instance_name} /hfc-data/
    }

    try_to_start_instance_by_id() {
        #
    }

    try_to_restore_instance_by_id() {
        #
    }
    # check docker daemon status by check dockerd version
    dockerd_version=`get_dockerd_version`

    if [[ ! ${dockerd_version} ]]; then
        # if dockerd is not running, try to start
        echo "ERROR: docker daemon is stopped !!!"
        echo "       Trying to restart docker daemon ..."

        # try to start docker daemon
        systemctl start docker.service

        # check docker daemon state also by check dockerd version
        daemon_state=`get_dockerd_version`
        if [[ ${daemon_state} ]]; then
            echo "INFO:  docker daemon restarted ..."
            echo "       Trying to restart all docker instances ..."

            # try to start all instances not in running state (exited, dead, paused)
            stopped_instances=`get_stopped_instances`
            for instance in ${stopped_instances} ; do
                # try to start ${instance}
                docker start ${instance}
                # check ${instance} state
                state=`is_instance_running "${instance}"`
                if [[ ! ${state} ]]; then
                    name=`docker ps -a -f id="${instance}" --format {{.Names}}`
                    echo "ERROR: instance id=${instance} name=${name} cannot be started !!!"
                fi
            done
            # add more steps about restore the target_instance
        else
            echo "ERROR: docker daemon cannot started !!!"
            echo "       Exit recovery operation now ..."
            exit 1
        fi
    else
        # if dockerd is running, try to start the target_instance
        # check the ${target_instance_id} exists or not
        target_instance_name=`get_name_by_id "${target_instance_id}"`
        if [[ ! ${target_instance_name} ]]; then
            echo "ERROR: the target instance id=${target_instance_id} is not found !!!"
            echo "       IS IT running on this host???"
            # try to restore???
        fi

        # if the ${target_instance_id} exists, then check it's state
        state=`is_instance_running "${target_instance_id}"`
        if [[ ! ${state} ]]; then
            # execute docker start if ${target_instance_id} is not running
            docker start ${target_instance_id}
            # verify ${target_instance_id} state after restarted
            state=`is_instance_running "${target_instance_id}"`
            if [[ ! ${state} ]]; then
                # try to restore from existing latest restore folder if verify failed
                # target path is /hfc-data/${target_instance_name}/restore
                echo "ERROR: target instance id=${target_instance_id} name=${target_instance_name} cannot be started !!!"
                echo "       Try to restore from backup ..."

                if [[ -f "/hfc-data/${target_instance_name}/restore/run-${target_instance_name}.sh" ]]; then
                    # if exists, just run the script to restore
                    bash /hfc-data/${target_instance_name}/restore/run-${target_instance_name}.sh --force
                else
                    # if failed, try to restore from local backup tgz file
                    target_instance_image=`get_image_by_id "${target_instance_id}"`
                    latest_tgz=`get_backup_file_by_image "${target_instance_name}" "${target_instance_image}"`

                    if [[ ${latest_tgz} ]]; then
                        # extract ${latest_tgz} to ${temp_dir}
                        temp_dir=$(mktemp -d)
                        tar -zxf ${latest_tgz} -C ${temp_dir}

                        # move ${temp_dir}/hfc-data/${target_instance_name} to /hfc-data/
                        TIME_STAMP=`get_timestamp`
                        if [[ -e "/hfc-data/${target_instance_name}" ]]; then
                            mv -f /hfc-data/${target_instance_name} /hfc-data/${target_instance_name}.${TIME_STAMP}
                        fi

                        # make sure /hfc-data exists, for some cases that the volume may not mounted to the host
                        mkdir -p /hfc-data/
                        mv -f ${temp_dir}/hfc-data/${target_instance_name} /hfc-data/

                        # run the script to restore ${target_instance_id}
                        bash /hfc-data/${target_instance_name}/restore/run-${target_instance_name}.sh --force
                    else
                        echo "ERROR: NO backup tgz file found!!!"
                        echo "       target instance id=${target_instance_id} name=${target_instance_name} cannot be restored"
                        echo "       MUST check it manually !!!"
                    fi

                fi
                # verify ${target_instance_id} state after restored
                state=`is_instance_running "${target_instance_id}"`
                if [[ ! ${state} ]]; then
                    echo "ERROR: target instance id=${target_instance_id} name=${target_instance_name} was restored but cannot started !!!"
                    echo "       MUST check it manually !!!"
                fi
            fi
        else
            echo "WARN:  instance id=${target_instance_id} is already running !!!"
            echo "       There must be something wrong with the monitoring system or network !!!"
        fi
    fi

}