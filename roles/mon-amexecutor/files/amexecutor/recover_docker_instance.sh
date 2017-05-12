#!/bin/bash

#
# recover_docker_instance.sh
#   usage: bash recover_docker_instance.sh "${target_instance_id}"
#   note: must be running by root
#

#
# get args from stdin
#
target_instance_id=$1

#
# set global variables
#
export _file_name=$(readlink -f $0)
export _script_name=$(basename ${_file_name})
export _dir_name=$(dirname ${_file_name})

#
# precheck script status by checking pid
#   VERY IMPORTANT: there are some cases that some script is running and caused the container down for temporarily
#                   eg: fabric-backup.sh, monitoring-backup.sh, dnsmasq-backup.sh AND recover_docker_instance.sh
#               SO: these script share the same pidfile in order to avoid run these scripts at the sametime
#                   It is hardcoded to be /var/run/hfc-jcloud-com-backup-restore.pid
#
export pidfile="/var/run/hfc-jcloud-com-backup-restore.pid"
export retry_interval=5

echo "INFO:  prechecking before running this script ..."

# totally try to check for (1 + 3) * ${retry_interval} seconds
exist_pid=`cat ${pidfile} 2>/dev/null`

if [[ -e "${pidfile}" ]] && [[ "${exist_pid}" != "$$" ]] ; then
    echo "WARN:  \"${exist_pid_cmd}\" is running ..."
    echo "WARN:   we will retry after ${retry_interval}s ..."
    sleep ${retry_interval}
    # try sleep 3 more times before exit
    for cnt in {1..3}; do
        exist_pid=`cat ${pidfile} 2>/dev/null`
        echo "WARN:  this is the ${cnt} retry ..."
        if [[ -e "${pidfile}" ]] && [[ "${exist_pid}" != "$$" ]] ; then
            echo "WARN:  \"${exist_pid_cmd}\" is running ..."
            echo "WARN:   we will retry after ${retry_interval}s ..."
        fi
        sleep ${retry_interval}
    done
    # exit after 1 + 3 checks
    exist_pid_cmd=`ps -o cmd --no-headers ${exist_pid}`
    echo "WARN:  \"${exist_pid_cmd}\" is running ..."
    echo "WARN:  so we exit with nothing did ..."
    exit 1
fi

echo "INFO:  >>>> ${_script_name} started at `date +"%F %T(%:z)"` <<<<"

#
# write current pid to ${pidfile}
#
trap "rm -f -- \"${pidfile}\"" EXIT INT KILL TERM
echo "$$" > "${pidfile}"

#
# functions predefined
#
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

is_instance_running_by_id() {
    local instance_id=$1
    printf "`docker ps -qa -f "status=running" -f id="${instance_id}"`"
}

is_instance_running_by_name() {
    local instance_name=$1
    printf "`docker ps -qa -f "status=running" -f name="${instance_name}"`"
}

get_id_by_name() {
    local instance_name=$1
    printf "`docker ps -qa -f name="${instance_name}"`"
}


get_backup_file_by_image() {
    #
    # usage: get_backup_file_by_image "${instance_name}" "${instance_image}"
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
    # usage: set_restore_file_from_backup_tgz "${backup_tgz}"
    # backup_tgz should be tar.gz file with full path archived
    #                   eg: /hfc-data/ca.org1.hfc.jcloud.com
    #                   backup tgz file name: ca.org1.hfc.jcloud.com_20170511-105501-998.tgz
    #
    local backup_tgz=$1

    local instance_name=`echo ${backup_tgz} | cut -d '_' -f 1`
    local timestamp=`get_timestamp`

    # backup existing /hfc-data/${instance_name}
    local target_dir=/hfc-data/${instance_name}
    if [[ -e "${target_dir}" ]]; then
        mv -f ${target_dir} ${target_dir}.${timestamp}
    fi

    # replace with backup file
    temp_dir=$(mktemp -d)
    tar -zxf ${backup_tgz} -C ${temp_dir}

    # make sure /hfc-data exists, for some cases that the volume may not mounted to the host
    mkdir -p /hfc-data/
    mv -f ${temp_dir}/hfc-data/${instance_name} /hfc-data/
}

#
# main process
#

# 0. precheck the ${target_instance_id}
if [[ ! ${target_instance_id} ]]; then
    echo "ERROR: no instance_id provided !!!"
    echo "ERROR: exited with nothing done !!!"
    exit 1
fi

# 1. check dockerd status, try to start if dockerd is not running
#    check dockerd running status by checking dockerd version
dockerd_version=`get_dockerd_version`

if [[ ! ${dockerd_version} ]]; then
    #    1.1 if dockerd is not running, try to start
    echo "ERROR: docker daemon is stopped !!!"
    echo "WARN:  trying to restart docker daemon ..."

    #    1.2 try to start dockerd
    systemctl start docker.service

    #    1.3 verify dockerd running status again
    daemon_state=`get_dockerd_version`

    if [[ ! ${daemon_state} ]]; then
        echo "ERROR: docker daemon cannot started !!!"
        echo "ERROR: Exit recovery operation now ..."
        echo "INFO:  >>>> ${_script_name} finished at `date +"%F %T(%:z)"` <<<<"
        exit 1
    fi
fi

# 2. till now, dockerd should be running, try to start all instances status=exited/dead/paused
echo "INFO:  docker daemon is running ..."

echo "WARN:  trying to start all docker instances (exited, dead, paused) ..."
stopped_instances=`get_stopped_instances`
for instance in ${stopped_instances} ; do
    #    2.1 try to start ${instance}
    docker start ${instance}

    #    2.2 verify ${instance} state
    state=`is_instance_running_by_id "${instance}"`
    if [[ ! ${state} ]]; then
        name=`get_name_by_id "${instance}"`
        echo "ERROR: instance id=${instance} name=${name} cannot be started !!!"
    fi
done

# 3. try to start the target_instance, actually it should be started at step2.
#    3.1 set instance info
target_instance_name=`get_name_by_id "${target_instance_id}"`
target_instance_image=`get_image_by_id "${target_instance_id}"`
target_restore_dir="/hfc-data/${target_instance_name}/restore"
target_restore_script="run-${target_instance_name}.sh"

#    3.2 check the ${target_instance_id} exists or not
if [[ ! ${target_instance_name} ]]; then
    echo "ERROR: the target instance id=${target_instance_id} was not found !!!"
    echo "ERROR: IS id=${target_instance_id} running on this host???"
    echo "ERROR: Exit recovery operation now ..."
    echo "INFO:  >>>> ${_script_name} finished at `date +"%F %T(%:z)"` <<<<"
    exit 1
fi

#    3.3 check ${target_instance_id} running state
state=`is_instance_running_by_id "${target_instance_id}"`
if [[ ! ${state} ]]; then
    #    3.3.1 start ${target_instance_id} if not running
    docker start ${target_instance_id}

    #    3.3.2 verify ${target_instance_id} state
    state=`is_instance_running_by_id "${target_instance_id}"`
    if [[ ! ${state} ]]; then
        echo "ERROR: target instance id=${target_instance_id} name=${target_instance_name} cannot be started !!!"

        #    3.3.2.1 try to restore from backup if start failed
        echo "WARN:  Try to restore from backup ..."

        #    3.3.2.1.1 check ${target_restore_script} exists or not
        if [[ ! -f "${target_restore_dir}/${target_restore_script}" ]]; then
            echo "WARN:  ${target_restore_dir}/${target_restore_script} is not found !!!"
            echo "WARN:  try to recover from backup tgz file ..."

            #    3.3.2.1.2 try to recover from ${latest_backup_tgz} if not found
            latest_backup_tgz=`get_backup_file_by_image "${target_instance_name}" "${target_instance_image}"`

            if [[ ! ${latest_backup_tgz} ]]; then
                echo "ERROR: NO backup tgz file found !!!"
                echo "ERROR: target instance id=${target_instance_id} name=${target_instance_name} cannot be restored !!!"
                echo "ERROR: IS IT the right host??? CHECK it manually !!!"
                echo "ERROR: Exit recovery operation now ..."
                exit 1
            else
                #    3.3.2.1.3 extract /hfc-data/${target_instance_name} files
                echo "INFO:  recover restore files from ${latest_backup_tgz} ..."
                set_restore_file_from_backup_tgz "${latest_backup_tgz}"
            fi
        fi
        #    3.3.2.2 try to restore ${target_instance_id} by run ${target_restore_script}
        echo "INFO:  try to restore target instance id=${target_instance_id} name=${target_instance_name} now ..."
        cd ${target_restore_dir}
        bash ${target_restore_script} --force
        cd ${_dir_name}

        #    3.3.3.3 verify ${target_instance_id} state after restored
        #            NOTE, have to verify by ${target_instance_name} here, cause the id was changed after restore!!!
        state=`is_instance_running_by_name "${target_instance_name}"`
        if [[ ! ${state} ]]; then
            echo "ERROR: target instance id=${target_instance_id} name=${target_instance_name} was restored but cannot started !!!"
            echo "ERROR: CHECK it manually !!!"
            echo "ERROR: Exit recovery operation now ..."
            echo "INFO:  >>>> ${_script_name} finished at `date +"%F %T(%:z)"` <<<<"
            exit 1
        fi
        new_instance_id=`get_id_by_name "${target_instance_name}"`
        echo "INFO:  target instance id=${target_instance_id} name=${target_instance_name} restored successfully ..."
        echo "INFO:  the restore instance is id=${new_instance_id} name=${target_instance_name} ..."
    fi
else
    echo "WARN:  instance id=${target_instance_id} is already running !!!"
    echo "WARN:  There must be something wrong with the monitoring system or network !!!"
    echo "INFO:  >>>> ${_script_name} finished at `date +"%F %T(%:z)"` <<<<"
fi
