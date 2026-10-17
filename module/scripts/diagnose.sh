#!/system/bin/sh
# Guardian - diagnostics.  Run from a root shell:
#   su -c 'sh /data/adb/modules/saptak_guardian/scripts/diagnose.sh'

MODDIR=${0%/*}
MODDIR=${MODDIR%/scripts}
. "$MODDIR/scripts/common.sh"

load_conf
tgt=$(hosts_target)

echo "Guardian diagnostics"
echo "===================="
echo "module dir     : $MODDIR"
echo "data dir       : $DATA"
echo "toggles        : master=$master ads=$ads gambling=$gambling porn=$porn"
echo "source file    : $HOSTS  ($(count_blocked) domains)"
echo "target         : $tgt"
echo "source context : $(hosts_context)"
echo "target context : $(ls -Zd "$tgt" 2>/dev/null | awk '{print $1}')"
if is_mounted; then echo "mount          : mounted"; else echo "mount          : NOT mounted"; fi
if label_ok; then echo "label          : ok"; else echo "label          : WRONG - netd will be denied"; fi
echo

echo "live check - what the DNS resolver actually reads:"
live=$(live_blocked)
echo "  $tgt currently holds $live blocked entries"
if [ "$master" = "0" ]; then
    echo "  => master switch is OFF, nothing should be blocked"
elif [ "$live" -gt 100 ]; then
    echo "  => blocking is ACTIVE"
else
    echo "  => blocking is NOT active (mount missing or stale)"
fi
echo

echo "mount table entry:"
grep " $tgt " /proc/self/mountinfo 2>/dev/null | head -2
echo

echo "recent netd denials (should be empty):"
dmesg 2>/dev/null | grep -i 'name="hosts"' | tail -3
logcat -d 2>/dev/null | grep -i 'name="hosts"' | tail -3
echo

echo "log tail:"
tail -12 "$LOG" 2>/dev/null
