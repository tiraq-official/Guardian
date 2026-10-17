#!/system/bin/sh
# Guardian - WebUI backend. Every command prints exactly one JSON line.
#
#   status                 -> current state
#   set <key> <0|1>        -> flip a toggle (master|ads|gambling|porn)
#   rebuild                -> rebuild the hosts file + remount
#   update                 -> download fresh lists, rebuild, remount

MODDIR=${0%/*}
MODDIR=${MODDIR%/scripts}
. "$MODDIR/scripts/common.sh"

case "$1" in
    status)
        status_json
        ;;
    set)
        if set_conf "$2" "$3"; then
            status_json
        else
            printf '{"ok":false,"error":"bad argument"}\n'
            exit 1
        fi
        ;;
    rebuild)
        ensure_data
        build_hosts
        mount_hosts
        status_json
        ;;
    update)
        sh "$MODDIR/scripts/update_lists.sh" >> "$LOG" 2>&1
        build_hosts
        mount_hosts
        status_json
        ;;
    *)
        printf '{"ok":false,"error":"unknown command"}\n'
        exit 1
        ;;
esac
