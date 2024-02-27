#!/bin/bash

ATTACHMENT=""
ARTIFACTORIAL_URL=""
CURL_VERBOSE_FLAG=""
FAILURE_RETURN_VALUE=0
SPLIT_BLOCK_SIZE=1MB

usage() {
    echo "Usage: $0 [-a <attachment>] [-u <artifactorial_url>] [-v] [-r] -b <split_block_size>" 1>&2
    echo "  -a attachment           Path to the file to upload" 1>&2
    echo "  -u squad_url            SQUAD_URL where the attachment will be uploaded to" 1>&2
    echo "                          This script will try to fetch the SQUAD_ARCHIVE_SUBMIT_TOKEN" 1>&2
    echo "                          token from (lava_test_dir)/secrets or environments for the upload." 1>&2
    echo "  -v      Pass -v (verbose) flag to curl for debugging." 1>&2
    echo "  -r      Report failure. If the upload fails and this flag is set, the script will exit" 1>&2
    echo "          with return value 1. If the upload is skipped (no URL or no token found)," 1>&2
    echo "          this script will still return 0." 1>&2
    echo "  -b split block size      The size used to split the original file when it's too large" 1>&2
    exit 1
}

while getopts ":a:u:b:vr" opt; do
    case "${opt}" in
        a) ATTACHMENT="${OPTARG}" ;;
        u) ARTIFACTORIAL_URL="${OPTARG}" ;;
        b) SPLIT_BLOCK_SIZE="${OPTARG}" ;;
        v) CURL_VERBOSE_FLAG="-v" ;;
        r) FAILURE_RETURN_VALUE=1 ;;
        *) usage ;;
    esac
done

if [ -z "${ARTIFACTORIAL_URL}" ]; then
    echo "test-attachment skip"
    command -v lava-test-case > /dev/null 2>&1 && lava-test-case "test-attachment" --result "skip"
    exit 0
fi

function upload_one_file(){
   local f_target="${1}"
   local squad_url="${2}"
   local squad_token="${3}"
   local curl_verbose_flag="${4}"
   local file_id="${5}"

   attachmentBasename="$(basename "${f_target}")"
   testcase_name="test-attachment"
   [ -n "${file_id}" ] && testcase_name="test-attachment-${file_id}"

   # shellcheck disable=SC2086
   curl_array=("curl")
   [ -n "${curl_verbose_flag}" ] && curl_array+=("${curl_verbose_flag}")
   curl_array+=("--header" "Auth-Token: ${squad_token}")
   curl_array+=("--form" "attachment=@${f_target}")
   curl_array+=("${squad_url}")

   # return is the squad testrun id
   #return=$(curl ${curl_verbose_flag} --header "Auth-Token: ${squad_token}" --form "attachment=@${f_target}" "${squad_url}")
   #return=$(${curl_array[*]}) is the wrong format, it will be run as one string instead of separate parameters
   return=$("${curl_array[@]}")

   if echo "${return}" | grep -E "^[0-9]+$"; then
       # ARTIFACTORIAL_URL will be in the format like this:
       #    https://qa-reports.linaro.org/api/submit/squad_group/squad_project/squad_build/environment
       # shellcheck disable=SC2001
       url_squad_host=$(echo "${squad_url}"|sed 's|/api/submit/.*||')
       url_uploaded="${url_squad_host}/api/testruns/${return}/attachments/?filename=${attachmentBasename}"
       lava-test-reference "${testcase_name}" --result "pass" --reference "${url_uploaded}"
   else
       echo "${testcase_name} fail"
       echo "Expected one SQUAD testrun id returend, but curl returned \"${return}\"."
       command -v lava-test-case > /dev/null 2>&1 && lava-test-case "${testcase_name}" --result "fail"
       exit "${FAILURE_RETURN_VALUE}"
   fi
}

if command -v lava-test-reference > /dev/null 2>&1; then
    # The 'SQUAD_ARCHIVE_SUBMIT_TOKEN' needs to be defined in 'secrects' dictionary in job
    # definition file, or defined in the environment, it will be used.
    # One issue here Milosz pointed out:
    #    If there is lava_test_results_dir set in the job context, "/lava-*" might not be correct.
    lava_test_dir="$(find /lava-* -maxdepth 0 -type d | grep -E '^/lava-[0-9]+' 2>/dev/null | sort | tail -1)"
    if test -f "${lava_test_dir}/secrets"; then
        # shellcheck disable=SC1090
        . "${lava_test_dir}/secrets"
    fi

    if [ -z "${SQUAD_ARCHIVE_SUBMIT_TOKEN}" ]; then
        echo "WARNING: SQUAD_ARCHIVE_SUBMIT_TOKEN is empty! File uploading skipped."
        echo "test-attachment skip"
        command -v lava-test-case > /dev/null 2>&1 && lava-test-case "test-attachment" --result "skip"
        exit 0
    fi

    # print the size information for check
    ls -l "${ATTACHMENT}"
    echo "Try to split the original ${ATTACHMENT} into ${SPLIT_BLOCK_SIZE} files for uploading"
    split -b "${SPLIT_BLOCK_SIZE}" -d --additional-suffix=.split "${ATTACHMENT}"  "${ATTACHMENT}."
    ls -l "${ATTACHMENT}"*
    # shellcheck disable=SC2012
    split_numbers=$(ls -l "${ATTACHMENT}".*.split|wc -l)
    #file_size=$(wc -c "${ATTACHMENT}"|awk '{print $1}')
    if [ "${split_numbers}" -eq 0 ]; then
        echo "test-attachment fail"
        echo "Failed to get split file numbers"
        command -v lava-test-case > /dev/null 2>&1 && lava-test-case "test-attachment" --result "fail"
        exit "${FAILURE_RETURN_VALUE}"
    fi

    # curl_array=("curl")
    # [ -n "${CURL_VERBOSE_FLAG}" ] && curl_array+=("${CURL_VERBOSE_FLAG}")
    # curl_array+=("--header" "Auth-Token: ${SQUAD_ARCHIVE_SUBMIT_TOKEN}")

    # if the file size is greater than the ${SPLIT_BLOCK_SIZE} specified
    if [ "${split_numbers}" -eq 1 ]; then
        echo "Uploading the original ${ATTACHMENT}"
        # curl_array+=("--form" "attachment=@${ATTACHMENT}")
        upload_one_file "${ATTACHMENT}" "${ARTIFACTORIAL_URL}" "${SQUAD_ARCHIVE_SUBMIT_TOKEN}" "${CURL_VERBOSE_FLAG}" ""
    else
        for f in "${ATTACHMENT}".*.split; do
            # curl_array+=("--form" "attachment=@${f}")
            # f will in the format like xxx.tar.xz.01.split, and file_id will be 01
            file_id=$(echo "${f}"|rev | cut -d'.' -f2 | rev)
            echo "Trying to upload split file: $f"
            upload_one_file "${f}" "${ARTIFACTORIAL_URL}" "${SQUAD_ARCHIVE_SUBMIT_TOKEN}" "${CURL_VERBOSE_FLAG}" "${file_id}"
        done
    fi
    # curl_array+=("${ARTIFACTORIAL_URL}")
    # attachmentBasename="$(basename "${f_target}")"
    # testcase_name="test-attachment"
    # # return=$(${curl_array[*]}) is the wrong format, it will be run as one string instead of separate parameters
    # echo "${curl_array[@]}"
    # return=$("${curl_array[@]}")
    # if echo "${return}" | grep -E "^[0-9]+$"; then
    #     # ARTIFACTORIAL_URL will be in the format like this:
    #     #    https://qa-reports.linaro.org/api/submit/squad_group/squad_project/squad_build/environment
    #     url_squad_host=$(echo "${squad_url}"|sed 's|/api/submit/.*||')
    #     url_uploaded="${url_squad_host}/api/testruns/${return}/attachments/?filename=${attachmentBasename}"
    #     lava-test-reference "${testcase_name}" --result "pass" --reference "${url_uploaded}"
    # else
    #     echo "${testcase_name} fail"
    #     echo "Expected one SQUAD testrun id returend, but curl returned \"${return}\"."
    #     command -v lava-test-case > /dev/null 2>&1 && lava-test-case "${testcase_name}" --result "fail"
    #     exit "${FAILURE_RETURN_VALUE}"
    # fi
else
    echo "test-attachment skip"
    command -v lava-test-case > /dev/null 2>&1 && lava-test-case "test-attachment" --result "skip"
fi
