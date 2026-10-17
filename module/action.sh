#!/system/bin/sh
# Guardian - runs when the user taps the module's Action button.
# Flips the master switch and reports the result.

MODDIR=${0%/*}
. "$MODDIR/scripts/common.sh"

ensure_data
load_conf

if [ "$master" = "1" ]; then
    set_conf master 0
    echo "Guardian: master switch is now OFF (blocking paused)"
else
    set_conf master 1
    echo "Guardian: master switch is now ON ($(count_blocked) domains blocked)"
fi
