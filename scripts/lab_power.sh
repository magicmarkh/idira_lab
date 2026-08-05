#!/bin/bash
set -euo pipefail

# =====================================================================
# lab_power.sh — start / stop / check the lab EC2 instances via AWS CLI
#
# Targets every instance whose Name tag begins with LAB_NAME_PREFIX
# (all lab instances are tagged "<team_name>-<hostname>", e.g. mh-west-dc).
#
# Usage:
#   ./lab_power.sh start      # boot all lab instances
#   ./lab_power.sh stop       # shut down all lab instances
#   ./lab_power.sh status     # show current state (default if no action)
#
# Overrides (env):
#   LAB_REGION       AWS region              (default: us-west-2)
#   LAB_NAME_PREFIX  Name-tag prefix filter  (default: mh-west)
#   AWS_PROFILE      standard AWS CLI profile selection
# =====================================================================

LAB_REGION="${LAB_REGION:-us-west-2}"
LAB_NAME_PREFIX="${LAB_NAME_PREFIX:-mh-west}"

# Colors
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RESET='\033[0m'

usage() {
    echo "Usage: $0 {start|stop|status}"
    echo ""
    echo "  start   boot all instances tagged Name=${LAB_NAME_PREFIX}-*"
    echo "  stop    shut down those instances"
    echo "  status  show current state (default)"
    echo ""
    echo "  Region: ${LAB_REGION}   Prefix: ${LAB_NAME_PREFIX}-*"
    exit 1
}

check_prerequisites() {
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}ERROR:${RESET} AWS CLI not found. Install: https://aws.amazon.com/cli/"
        exit 1
    fi
    if ! aws sts get-caller-identity --region "${LAB_REGION}" &> /dev/null; then
        echo -e "${RED}ERROR:${RESET} AWS credentials not valid for region ${LAB_REGION}."
        echo "Check your AWS login / AWS_PROFILE."
        exit 1
    fi
}

# Print "id\tstate\tname" lines for all matching instances (optionally
# restricted to a given state). Pass "" for any state.
query_instances() {
    local state_filter="$1"
    local filters=("Name=tag:Name,Values=${LAB_NAME_PREFIX}-*")
    if [[ -n "${state_filter}" ]]; then
        filters+=("Name=instance-state-name,Values=${state_filter}")
    fi

    aws ec2 describe-instances \
        --region "${LAB_REGION}" \
        --filters "${filters[@]}" \
        --query "Reservations[].Instances[].[InstanceId, State.Name, Tags[?Key=='Name']|[0].Value]" \
        --output text 2>/dev/null | sort -k3
}

show_status() {
    echo -e "${BLUE}Lab instances (${LAB_NAME_PREFIX}-*, ${LAB_REGION}):${RESET}"
    local rows
    rows="$(query_instances "")"
    if [[ -z "${rows}" ]]; then
        echo "  (none found)"
        return
    fi
    printf "  %-22s %-14s %s\n" "INSTANCE ID" "STATE" "NAME"
    while IFS=$'\t' read -r id state name; do
        [[ -z "${id}" ]] && continue
        local color="${RESET}"
        case "${state}" in
            running)  color="${GREEN}" ;;
            stopped)  color="${RED}" ;;
            *)        color="${YELLOW}" ;;
        esac
        printf "  %-22s ${color}%-14s${RESET} %s\n" "${id}" "${state}" "${name}"
    done <<< "${rows}"
}

# Collect just the instance IDs in a given state into a bash array named IDS.
collect_ids() {
    local state_filter="$1"
    IDS=()
    local rows
    rows="$(query_instances "${state_filter}")"
    while IFS=$'\t' read -r id _state _name; do
        [[ -n "${id}" ]] && IDS+=("${id}")
    done <<< "${rows}"
}

do_start() {
    collect_ids "stopped"
    if [[ ${#IDS[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No stopped instances to start.${RESET}"
        return
    fi
    echo -e "${GREEN}Starting ${#IDS[@]} instance(s):${RESET} ${IDS[*]}"
    aws ec2 start-instances --region "${LAB_REGION}" --instance-ids "${IDS[@]}" \
        --query "StartingInstances[].[InstanceId, CurrentState.Name]" --output text
}

do_stop() {
    collect_ids "running"
    if [[ ${#IDS[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No running instances to stop.${RESET}"
        return
    fi
    echo -e "${YELLOW}The following ${#IDS[@]} instance(s) will be STOPPED:${RESET} ${IDS[*]}"
    read -p "Continue? (yes/no): " confirm
    if [[ "${confirm}" != "yes" ]]; then
        echo "Aborted."
        exit 0
    fi
    aws ec2 stop-instances --region "${LAB_REGION}" --instance-ids "${IDS[@]}" \
        --query "StoppingInstances[].[InstanceId, CurrentState.Name]" --output text
}

main() {
    local action="${1:-status}"
    check_prerequisites
    case "${action}" in
        start)  do_start; echo ""; show_status ;;
        stop)   do_stop;  echo ""; show_status ;;
        status) show_status ;;
        -h|--help|help) usage ;;
        *) echo -e "${RED}Unknown action: ${action}${RESET}"; echo ""; usage ;;
    esac
}

main "$@"
