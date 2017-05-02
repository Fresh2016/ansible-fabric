#!/bin/bash

CONTAINER_NAME=$1
#CONTAINER_NAME=$(docker ps --format "{{.ID}}\t{{.Names}}" | awk '/peer[0-9]?$/ {print $2}')
DATA_SRC_DIR=/hfc-data/${CONTAINER_NAME}/
BACKUP_DEST_DIR=/var/lib/docker/dnsmasq-backup
TIME_STAMP=$(printf "%.19s" "$(date +%Y%m%d.%H%M%S.%N)")
BACKUP_FILENAME=${BACKUP_DEST_DIR}/${CONTAINER_NAME}.${TIME_STAMP}.tgz

export CONTAINER_NAME
export DATA_SRC_DIR
export BACKUP_DEST_DIR
export BACKUP_FILENAME

local_time() {
    printf "%.23s" "$(date '+%Y-%m-%d %H:%M:%S.%N')"
}

backup() {
    echo "==== Stopping ${CONTAINER_NAME} ..."
    docker stop ${CONTAINER_NAME}
    
    echo "==== Wait 1 second before backup ..."
    sleep 1
    
    echo "==== Backup ${DATA_SRC_DIR} to ${BACKUP_FILENAME}"
    mkdir -p ${BACKUP_DEST_DIR}
    tar -czf ${BACKUP_FILENAME} ${DATA_SRC_DIR}
    
    echo "==== Wait 1 second after backup ..."
    sleep 1
    
    echo "==== Starting ${CONTAINER_NAME} ..."
    docker start ${CONTAINER_NAME}
}

prune_old_backup() {
    DATE_LIMIT=$(date +%Y%m%d --date="-7 day")
    for BAK_FILE in $(ls ${BACKUP_DEST_DIR}); do
        BAK_DATE=$(echo ${BAK_FILE} | cut -d '.' -f 2)
        if [[ "${BAK_DATE}" -lt "${DATE_LIMIT}" ]]; then
            echo "---- Deleting ${BAK_FILE} ..."
            rm -f ${BAK_FILE}
        else
            echo "---- Skipping ${BAK_FILE} ..."
        fi
    done
}

LOG_FILE=/var/log/${CONTAINER_NAME}-backup.log

echo "==== BACKUP for ${CONTAINER_NAME} started @ $(local_time)"  > ${LOG_FILE}
backup 2>&1                                                       >> ${LOG_FILE}
prune_old_backup 2>&1                                             >> ${LOG_FILE}
echo "==== BACKUP for ${CONTAINER_NAME} finished @ $(local_time)" >> ${LOG_FILE}

