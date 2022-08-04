#!/bin/sh
set -eu

repo_path="$(cd "$(dirname "$0")" && pwd)"
cmdname="$(basename "$0")"

usage() {
    cat << USAGE >&2
Usage:
    $cmdname command

    Docker entrypoint script
    Wrapper script that executes docker-related tasks before running given command

USAGE
    exit 1
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
    exit 0
fi


write_env_to_json() {
    # write project-specific environment variables to app config file
    local json_file="$1"

    # only write environment variables frontend will read (beginning with "REACT_" or "VUE_")
    local json_contents="{$(printenv | grep -e REACT_ -e VUE_ | sed 's/^\|$/"/g' | sed 's|=|":"|' | paste -sd, -)}"
    echo "$json_contents" > "$json_file"
}


write_env_to_json /usr/share/nginx/html/env.json


echo $cmdname complete
echo executing given command $@
exec "$@"
