#!/system/bin/sh
# Guardian - cleanup on module removal.
# Lift the bind mount so the stock hosts file is restored on the next reboot.

tgt=/system/etc/hosts
[ -e "$tgt" ] || tgt=/etc/hosts
umount "$tgt" 2>/dev/null
umount /etc/hosts 2>/dev/null

# The working data in /data/adb/guardian is intentionally kept, so that a
# re-install keeps your settings and downloaded lists.
