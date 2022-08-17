#
# bash functions to support CI/CD jobs for ufs-srweather-app (SRW) 
# Usage: [SRW_DEBUG=true] source srw_functions.sh
#
[[ ${SRW_DEBUG} == true ]] && echo "SRW_COMPILER=${SRW_COMPILER:-"intel"}"

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

[[ ${SRW_DEBUG} == true ]] && ( set | grep "()" | grep "^SRW_" )
