#!/system/bin/sh
# Guardian - runs at late_start. Re-applies the bind mount (some ROMs reset
# mounts during boot) and optionally refreshes the blocklists.

MODDIR=${0%/*}
. "$MODDIR/scripts/common.sh"

# wait (bounded) for the system to finish booting
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$i" -lt 120 ]; do
    sleep 2
    i=$((i + 1))
done

ensure_data

if needs_build; then
    build_hosts
fi

mount_hosts

# Optional automatic refresh of the lists (off by default; toggle with
# `autoupdate=1` in /data/adb/guardian/config.conf).
load_conf
if [ "$autoupdate" = "1" ]; then
    last=0
    [ -f "$STAMP.epoch" ] && last=$(cat "$STAMP.epoch" 2>/dev/null)
    now=$(date +%s)
    case "$last" in ''|*[!0-9]*) last=0;; esac
    if [ "$last" -gt 0 ] && [ $((now - last)) -gt 604800 ]; then
        sh "$MODDIR/scripts/update_lists.sh" >> "$LOG" 2>&1
        build_hosts
        mount_hosts
    fi
fi
