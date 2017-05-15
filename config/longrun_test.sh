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
    QUERY_RET=$(/jcloud-blockchain/verify.js -l 7 2>/dev/null | awk -F ':' '/CURRENT_BLOCK_NUMBER/ {print $2}')
    printf "$QUERY_RET"
}

counter=1

# the first query may failed, so the invoke_start will be null
invoke_start=$(query_test)
invoke_success_count=${invoke_start}
while true; do
    printf ">>>>>> Test - ${counter} - Started  @ `long_time` <<<<<<\n"
    format_output invoke_test

    INVOKE_RET=$(query_test)
    if [[ ${INVOKE_RET} ]]; then
        invoke_success_count=${INVOKE_RET}
    fi

    # if invoke_start is null, just set to the first invoke_success_count - 1 + counter
    if [[ ! ${invoke_start} ]]; then
        invoke_start=${invoke_success_count}
        let invoke_start=invoke_start-1
        let invoke_start=invoke_start+counter
    fi

    invoke_success_total=`echo ${invoke_success_count}-${invoke_start} | bc -l`
    test_total=${counter}
    test_failed=`echo ${test_total}-${invoke_success_total} | bc -l`
    invoke_success_rate=`echo ${invoke_success_total}/${test_total}*100 | bc -l`
    printf "+-------------------------------------+\n"
    printf "| invoke success # >> %-8s     << |\n"     "${invoke_success_total}"
    printf "| invoke test    # >> %-8s     << |\n"     "${test_total}"
    printf "| invoke failed  # >> %-8s     << |\n"     "${test_failed}"
    printf "| success rate   %% >> %-8.4f%%    << |\n" "${invoke_success_rate}"
    printf "| current block  # >> %-8s     << |\n"     "${invoke_success_count}"
    printf "+-------------------------------------+\n"
    printf ">>>>>> Test - ${counter} - Finished @ `long_time` <<<<<<\n\n\n"

    let counter+=1
done
