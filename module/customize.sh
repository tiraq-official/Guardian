#!/system/bin/sh
# ============================================================================
#  Guardian installer - runs at flash time.
#  Compatible with Magisk, KernelSU / KernelSU-Next, APatch, FolkPatch, SukiSU.
# ============================================================================
SKIPUNZIP=0

# Fallbacks in case the manager does not expose Magisk's helpers.
type ui_print >/dev/null 2>&1 || ui_print() { echo "$1"; }
type set_perm >/dev/null 2>&1 || set_perm() {
    chown "$2:$3" "$1" 2>/dev/null
    chmod "$4" "$1" 2>/dev/null
}
type set_perm_recursive >/dev/null 2>&1 || set_perm_recursive() {
    chown -R "$2:$3" "$1" 2>/dev/null
    find "$1" -type d -exec chmod "$4" {} + 2>/dev/null
    find "$1" -type f -exec chmod "$5" {} + 2>/dev/null
}

ui_print " "
ui_print "  ########################################"
ui_print "  #            G U A R D I A N           #"
ui_print "  #   Ad - Gambling - Adult  blocker     #"
ui_print "  #          by Saptak Maji              #"
ui_print "  ########################################"
ui_print " "

# executable scripts
for f in post-fs-data.sh service.sh action.sh uninstall.sh; do
    [ -f "$MODPATH/$f" ] && set_perm "$MODPATH/$f" 0 0 0755
done
[ -d "$MODPATH/scripts" ] && set_perm_recursive "$MODPATH/scripts" 0 0 0755 0755
[ -d "$MODPATH/webroot" ] && set_perm_recursive "$MODPATH/webroot" 0 0 0755 0644
[ -d "$MODPATH/lists" ]   && set_perm_recursive "$MODPATH/lists"   0 0 0755 0644

ui_print "- Bundled blocklists:"
for c in ads gambling porn; do
    n=$(wc -l < "$MODPATH/lists/$c.txt" 2>/dev/null || echo 0)
    ui_print "    $c: $n domains"
done

# Seed the persistent working directory.
mkdir -p /data/adb/guardian/lists
cp -f "$MODPATH/lists/ads.txt"      /data/adb/guardian/lists/ads.txt      2>/dev/null
cp -f "$MODPATH/lists/gambling.txt" /data/adb/guardian/lists/gambling.txt 2>/dev/null
cp -f "$MODPATH/lists/porn.txt"     /data/adb/guardian/lists/porn.txt     2>/dev/null
chmod 644 /data/adb/guardian/lists/*.txt 2>/dev/null

if [ ! -f /data/adb/guardian/config.conf ]; then
    printf 'master=1\nads=1\ngambling=1\nporn=1\nautoupdate=0\n' > /data/adb/guardian/config.conf
    chmod 644 /data/adb/guardian/config.conf
fi

date '+%Y-%m-%d' > /data/adb/guardian/lists/.updated 2>/dev/null
date '+%s'       > /data/adb/guardian/lists/.updated.epoch 2>/dev/null

ui_print "- Done. Reboot to activate."
ui_print " "
