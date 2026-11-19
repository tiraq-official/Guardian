#!/system/bin/sh
# Guardian - cleanup on module removal.

MODDIR=${0%/*}
# stop the resolver and drop its iptables redirect (if the resolver engine
# was in use) before the module disappears
if [ -f "$MODDIR/scripts/common.sh" ]; then
    . "$MODDIR/scripts/common.sh" 2>/dev/null
    cleanup_resolver 2>/dev/null
fi

# Lift the bind mount so the stock hosts file is restored on the next reboot.
tgt=/system/etc/hosts
[ -e "$tgt" ] || tgt=/etc/hosts
umount "$tgt" 2>/dev/null
umount /etc/hosts 2>/dev/null

# The working data in /data/adb/guardian is intentionally kept, so that a
# re-install keeps your settings and downloaded lists.
