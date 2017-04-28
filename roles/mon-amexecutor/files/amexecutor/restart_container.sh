#!/bin/bash
echo    ">> This is a test script, doing nothing <<"
echo    "------------------------------------------"
echo -e "\n\n$(env | grep ^AMX)\n\n"
echo -e "------------------------------------------\n\n\n"

CNT=1
while [ ${CNT} -le ${AMX_ALERT_LEN} ]; do
    echo "  >> processing the ${CNT} alert ..."
    eval "LABEL_ACTION=\${AMX_ALERT_${CNT}_LABEL_action}"
    eval "LABEL_INSTANCE=\${AMX_ALERT_${CNT}_LABEL_instance}"
    eval "LABEL_NAME=\${AMX_ALERT_${CNT}_LABEL_name}"
    echo "     AMX_ALERT_${CNT}_LABEL_action is: ${LABEL_ACTION}"
    echo "     Restarting ${LABEL_NAME} on ${LABEL_INSTANCE}"
    echo "  >> process finished"
    ((CNT+=1))
done
