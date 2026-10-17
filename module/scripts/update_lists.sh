#!/system/bin/sh
# Guardian - refresh the blocklists from upstream.
# Downloads every source, normalises to a plain domain list and writes
# /data/adb/guardian/lists/<category>.txt.  Keeps the previous list if a
# download fails or comes back suspiciously small.

MODDIR=${0%/*}
MODDIR=${MODDIR%/scripts}
. "$MODDIR/scripts/common.sh"

ensure_data

UA="Guardian-Blocklist/1.0"
TMP=$DATA/.dl
rm -rf "$TMP"
mkdir -p "$TMP"

HAGEZI="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard"

# category|url|format   (format: domains | hosts | adblock)
SOURCES="
ads|$HAGEZI/pro.plus-onlydomains.txt|domains
ads|https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts|hosts
ads|https://raw.githubusercontent.com/AdguardTeam/AdGuardSDNSFilter/master/Filters/rules.txt|adblock
gambling|$HAGEZI/gambling.mini-onlydomains.txt|domains
porn|$HAGEZI/nsfw-onlydomains.txt|domains
"

VALID='^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$'

fetch() { # url outfile
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -A "$UA" "$1" -o "$2" 2>/dev/null && return 0
    fi
    for bb in /data/adb/magisk/busybox /data/adb/ksu/bin/busybox /data/adb/ap/bin/busybox /system/bin/busybox; do
        if [ -x "$bb" ]; then
            "$bb" wget -q -U "$UA" -O "$2" "$1" 2>/dev/null && return 0
        fi
    done
    if command -v wget >/dev/null 2>&1; then
        wget -q -U "$UA" -O "$2" "$1" 2>/dev/null && return 0
    fi
    return 1
}

normalize() { # infile format
    case "$2" in
        hosts)   awk '/^[[:space:]]*[0-9]/ {print $2}' "$1" ;;
        domains) awk '!/^[[:space:]]*[#!]/ && NF {print $1}' "$1" ;;
        adblock) sed -n 's/^||\([^/^$|]*\).*/\1/p' "$1" ;;
    esac
}

i=0
for cat in ads gambling porn; do
    : > "$TMP/$cat.raw"
done

echo "$SOURCES" | while IFS='|' read -r cat url fmt; do
    [ -z "$cat" ] && continue
    i=$((i + 1))
    f="$TMP/$i.dl"
    if fetch "$url" "$f"; then
        normalize "$f" "$fmt" >> "$TMP/$cat.raw"
        log "update[$cat]: ok   $url"
    else
        log "update[$cat]: FAIL $url"
    fi
done

for cat in ads gambling porn; do
    [ -s "$TMP/$cat.raw" ] || { log "update[$cat]: nothing downloaded, keeping old"; continue; }
    tr 'A-Z' 'a-z' < "$TMP/$cat.raw" \
        | sed 's/^\.//; s/\.$//' \
        | grep -E "$VALID" \
        | sort -u > "$TMP/$cat.txt"

    cnt=$(wc -l < "$TMP/$cat.txt")
    old=$(wc -l < "$LISTS/$cat.txt" 2>/dev/null || echo 0)
    if [ "$cnt" -gt 1000 ]; then
        mv -f "$TMP/$cat.txt" "$LISTS/$cat.txt"
        chmod 644 "$LISTS/$cat.txt"
        log "update[$cat]: wrote $cnt domains (was $old)"
    else
        log "update[$cat]: only $cnt domains, keeping old ($old)"
    fi
done

stamp_now
rm -rf "$TMP"
log "update: finished"
