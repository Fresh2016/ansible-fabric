#!/bin/bash
#
# Need bash, jq, bc
long_time() {
    printf "%.23s" "$(date '+%Y-%m-%d %H:%M:%S.%N')"
}

format_output() {
    $@ 2>&1 | while read -r line; do echo -e "\\t $line"; done
}

invoke_test() {
    /jcloud-blockchain/verify.js -l 6 2>&1 > /dev/null
}

query_test() {
    #QUERY_RET=`./verify.js -l 7 | grep 'TESTAPP: queryBlocks info result' | sed 's/TESTAPP: queryBlocks info result//g' | jq '.message.Payloads.low' 2>/dev/null`
    QUERY_RET=$(/jcloud-blockchain/verify.js -l 7 | awk -F ':' '/CURRENT_BLOCK_NUMBER/ {print $2}')
    printf "$QUERY_RET"
}

counter=$(query_test)
invoke_start=${counter}
invoke_success_count=${invoke_start}
while true; do
    ((counter+=1))
    printf ">>>>>> Test - ${counter} - Started  @ `long_time` <<<<<<\n"
    format_output invoke_test

    INVOKE_RET=$(query_test)
    if [[ ${INVOKE_RET} ]]; then
        invoke_success_count=${INVOKE_RET}
    fi

    invoke_success_total=`echo ${invoke_success_count}-${invoke_start} | bc -l`
    test_total=`echo ${counter}-${invoke_start} | bc -l`
    test_failed=`echo ${test_total}-${invoke_success_total} | bc -l`
    invoke_success_rate=`echo ${invoke_success_total}/${test_total}*100 | bc -l`
    printf "+-------------------------------------+\n"
    printf "| invoke success # >> %-8s     << |\n"     "${invoke_success_total}"
    printf "| invoke test    # >> %-8s     << |\n"     "${test_total}"
    printf "| invoke failed  # >> %-8s     << |\n"     "${test_failed}"
    printf "| success rate   %% >> %-8.4f%%    << |\n" "${invoke_success_rate}"
    printf "| current block  # >> %-8s     << |\n"     "${invoke_success_count}"
    printf "+-------------------------------------+\n"
    printf ">>>>>> Test - ${counter} - Finished @ `long_time` <<<<<<\n"
done
