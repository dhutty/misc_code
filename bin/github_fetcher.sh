#!/bin/bash
#
# Author: Duncan Hutty <dhutty@allgoodbits.org>
# Last Modified: 2017-07-03
# Usage: ./$0 [options]
#

# Requirements (and git, of course!)
# httpie:     http://httpie.org
# jq:         https://stedolan.github.io/jq/

set -o nounset  # error on referencing an undefined variable
set -o errexit  # exit on command or pipeline returns non-true
set -o pipefail # exit if *any* command in a pipeline fails, not just the last

SUMMARY="Clones/fetches all repositories from all or specified Organizations"
VERSION="0.1.0"
PROGNAME=$( basename "$0" )
verbosity=0
user=${GITHUB_USER:=$USER}
token=${GITHUB_TOKEN:="${HOME}/github_token"}
endpoint='api.github.com'
extra_opts=''

print_usage() {
    echo "${SUMMARY}"; echo ""
    echo "Usage: $PROGNAME [options] [list of Organizations]"
    echo ""

    echo "-e API endpoint, default: ${endpoint}"
    echo "-t path to file with token, default: ${GITHUB_TOKEN}"
    echo "-u username, default: ${GITHUB_USER}"

    echo "-h Print this usage"
    echo "-v Increase verbosity"
    echo "-V Print version number and exit"
}

print_help() {
        echo "$PROGNAME $VERSION"
        echo ""
        print_usage
}


while getopts "hvVe:o:t:u:" OPTION;
do
  case "$OPTION" in
    e)  endpoint=${OPTARG}
        ;;
    o)  extra_opts=${OPTARG}
        ;;
    t)  tokenfile=${OPTARG}
        ;;
    u)  user=${OPTARG}
        ;;
    h)
        print_usage
        exit 0
        ;;
    v)
        verbosity=$((verbosity+1))
        ;;
    V)
        echo "${VERSION}"
        exit 0
        ;;
    *)
        echo "Unrecognised Option: ${OPTARG}"
        exit 1
        ;;
  esac
done

token=$(cat "$tokenfile")
log() {  # standard logger
   local prefix="[$(date +%Y/%m/%d\ %H:%M:%S)]: "
   echo "${prefix}" "$@" >&2
}

[[ $verbosity -gt 1 ]] && set -x
shift $((OPTIND - 1))

if [ $# -gt 0 ]; then
    ORGS=$*
else
    ORGS=$(http -a "${user}:${token}" "https://${endpoint}/user/orgs" | jq '.[]|.login'|sed 's/"//g')
fi
[[ $verbosity -gt 0 ]] && log "Orgs: $ORGS"

WD=${PWD}
for org in $ORGS;
do mkdir -p "$org"; cd "$org";
    for repo in $(http -a "${user}:${token}" "https://${endpoint}/orgs/${org}/repos" | jq '.[]|.name' | sed -e 's/"//g');
    do
        # If -d ${repo}/.git then cd & fetch, else clone
        if [ -d "${repo}/.git" ]; then
            cd "${repo}"
            git fetch ${extra_opts}
            [[ $verbosity -gt 0 ]] && log "Fetching $org: $repo"
            cd -
        else
            git clone $(http -a "${user}:${token}" "https://${endpoint}/orgs/${org}/repos" | jq "map(select(.name == \"${repo}\"))|.[].ssh_url" | sed 's/"//g') $extra_opts
            [[ $verbosity -gt 0 ]] && log "Cloning $org: $repo"
        fi
    done;
    cd "${WD}"
done
