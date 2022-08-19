#
# bash functions to support CI/CD jobs for ufs-srweather-app (SRW) 
# Usage:
#     export NODE_NAME=<build_node>
#     export SRW_COMPILER="intel" | "gnu"
#     [SRW_DEBUG=true] source path/to/scripts/srw_functions.sh
#

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"

if [[ ${SRW_DEBUG} == true ]] ; then
    echo "script_file=$(pwd)/${BASH_SOURCE[0]}"
    #echo "script_dir=$script_dir"
    echo "export NODE_NAME=${NODE_NAME}"
    echo "export SRW_COMPILER=${SRW_COMPILER}"
    grep "^function " ${BASH_SOURCE[0]}
fi

function SRW_list_repos() # show a table of latest commit IDs of all repos/sub-repos at PWD
{
    local comment="$1"
    echo "$comment"
    for repo in $(find . -name .git -type d | sort) ; do
    (
        cd $(dirname $repo)
        SUB_REPO_NAME=$(git config --get remote.origin.url | sed 's|https://github.com/||g' | sed 's|.git$||g')
        SUB_REPO_STR=$(printf "%-40s%s\n" "$SUB_REPO_NAME~" "~" | tr ' ~' '  ')
        SUB_BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
        git log -1 --pretty=tformat:"# $SUB_REPO_STR %h:$SUB_BRANCH_NAME %d %s [%ad] <%an> " --abbrev=8 --date=short
    )
    done
}

function SRW_has_cron_entry() # Are there any srw-build-* experiment crons running?
{
    local dir=$1
    crontab -l | grep "ufs-srweather-app/srw-build-${SRW_COMPILER:-"intel"}/expt_dirs/$dir"
}

function SRW_wflow_status() # [internal] used to determine state of an e2e test
{
    local log_data="$1"
    local result=""
    local rc=0
    
    result=$(echo "$log_data" | cut -d: -f2-)
    if [[ 0 == $? ]]; then
        rc=1
        echo "$result" | egrep -i 'IN PROGRESS|SUCCESS|FAILURE' > /dev/null || result=PENDING
        [[ $result =~ PROGRESS ]] && rc=1
        [[ $result =~ SUCCESS ]] && rc=0
        [[ $result =~ FAILURE ]] && rc=0
    else
        result="Not Found" && rc=9
    fi
    echo "$result"
    return $rc
}

function SRW_get_details() # Use rocotostat to generate detailed test results
{
    local startTime="$1"
    local opt="$2"
    local log_file=""
    local workspace=${WORKSPACE:-"."}
    echo ""
    echo "#### started $startTime"
    echo "#### checked $(date)"
    echo "#### ${SRW_COMPILER}-${PLATFORM:-"${NODE_NAME,,}"} ${JOB_NAME:-$(git config --get remote.origin.url 2>/dev/null)} -b ${GIT_BRANCH:-$(git symbolic-ref --short HEAD 2>/dev/null)}"
    echo "#### rocotostat -w "FV3LAM_wflow.xml" -d "FV3LAM_wflow.db" -v 10 $opt"
    echo ""
    for dir in $(cat ${WORKSPACE}/regional_workflow/tests/WE2E/expts_file.txt 2>/dev/null) ; do
        log_file=$(cd ${WORKSPACE}/expt_dirs/$dir/ 2>/dev/null && ls -1 log.launch_* 2>/dev/null)
        (
        echo "# rocotostat $dir/$log_file:"
        cd ${WORKSPACE}/expt_dirs/$dir/ && rocotostat -w "FV3LAM_wflow.xml" -d "FV3LAM_wflow.db" -v 10 $opt 2>/dev/null
        echo ""
        )
    done
    echo "####"
}

function SRW_save_tests() # Save SRW E2E tests to persistent storage, cluster_noaa hosts only 
{
    local SRW_SAVE_DIR="$1"
    echo "#### Saving SRW tests to ${SRW_SAVE_DIR}/${NODE_NAME}/$day_of_week/expt_dirs.tar"
    [[ -n ${SRW_SAVE_DIR} ]] && [[ -d ${SRW_SAVE_DIR} ]] || return 1
    [[ -n ${NODE_NAME} ]] || return 2
    if [[ ${NODE_NAME} =~ cluster_noaa ]] && [[ -d ${SRW_SAVE_DIR} ]] ; then
        day_of_week="$(date '+%u')"
        mkdir -p ${SRW_SAVE_DIR}/${NODE_NAME}/$day_of_week || return 3
        echo "#### Saving SRW tests to ${SRW_SAVE_DIR}/${NODE_NAME}/$day_of_week/expt_dirs.tar"
        tar cvpf ${SRW_SAVE_DIR}/${NODE_NAME}/$day_of_week/expt_dirs.tar \
            build_properties.txt \
            builder.env builder.txt \
            build-info.env build-info.txt \
            launch-info.env launch-info.txt \
            test-results-*-*.txt test-details-*-*.txt \
            regional_workflow/tests/WE2E/expts_file.txt expt_dirs
        if [[ 0 == $? ]] ; then
            ( cd ${SRW_SAVE_DIR}/${NODE_NAME} && rm -f latest && ln -s $day_of_week latest )
        fi
    fi
}

#[[ ${SRW_DEBUG} == true ]] && ( set | grep "()" | grep "^SRW_" )
