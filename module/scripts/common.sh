#!/system/bin/sh
# ============================================================================
#  Guardian - shared helpers
#  Sourced by post-fs-data.sh, service.sh, action.sh and scripts/webui.sh.
#  Everything the module needs to build the hosts file and bind-mount it.
# ============================================================================

MODID=saptak_guardian
MODDIR=${MODDIR:-/data/adb/modules/$MODID}
DATA=${DATA:-/data/adb/guardian}
CONF=$DATA/config.conf
HOSTS=$DATA/hosts
LISTS=$DATA/lists
BUNDLED=$MODDIR/lists
LOG=$DATA/guardian.log
STAMP=$DATA/lists/.updated

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG" 2>/dev/null
}

# ---------------------------------------------------------------------------
#  Data directory + first-run seeding
# ---------------------------------------------------------------------------
ensure_data() {
    mkdir -p "$DATA" "$LISTS" 2>/dev/null
    chmod 755 "$DATA" "$LISTS" 2>/dev/null

    if [ ! -f "$CONF" ]; then
        printf 'master=1\nads=1\ngambling=1\nporn=1\nautoupdate=0\n' > "$CONF"
        chmod 644 "$CONF"
        log "created default config"
    fi

    # Seed the working lists from the copy bundled in the module zip.
    for c in ads gambling porn; do
        if [ ! -s "$LISTS/$c.txt" ] && [ -s "$BUNDLED/$c.txt" ]; then
            cp -f "$BUNDLED/$c.txt" "$LISTS/$c.txt" 2>/dev/null
            chmod 644 "$LISTS/$c.txt" 2>/dev/null
            log "seeded list: $c"
        fi
    done

    [ -f "$STAMP" ] || date '+%Y-%m-%d' > "$STAMP" 2>/dev/null
}

# ---------------------------------------------------------------------------
#  Config
# ---------------------------------------------------------------------------
load_conf() {
    master=1; ads=1; gambling=1; porn=1; autoupdate=0
    [ -f "$CONF" ] && . "$CONF"
    case "$master"    in 0|1) ;; *) master=1;;    esac
    case "$ads"       in 0|1) ;; *) ads=1;;       esac
    case "$gambling"  in 0|1) ;; *) gambling=1;;  esac
    case "$porn"      in 0|1) ;; *) porn=1;;      esac
    case "$autoupdate" in 0|1) ;; *) autoupdate=0;; esac
}

save_conf() {
    printf 'master=%s\nads=%s\ngambling=%s\nporn=%s\nautoupdate=%s\n' \
        "$master" "$ads" "$gambling" "$porn" "$autoupdate" > "$CONF"
    chmod 644 "$CONF"
}

# ---------------------------------------------------------------------------
#  Build the hosts file
# ---------------------------------------------------------------------------
needs_build() {
    [ -f "$HOSTS" ] || return 0
    [ "$CONF" -nt "$HOSTS" ] && return 0
    for c in ads gambling porn; do
        [ -f "$LISTS/$c.txt" ] && [ "$LISTS/$c.txt" -nt "$HOSTS" ] && return 0
    done
    return 1
}

build_hosts() {
    ensure_data
    load_conf

    tmp="$DATA/.hosts.new"
    dtmp="$DATA/.domains.new"

    {
        echo "127.0.0.1 localhost"
        echo "::1 localhost"
        echo "#"
        echo "# Guardian hosts file"
        echo "# generated : $(date)"
        echo "# master=$master ads=$ads gambling=$gambling porn=$porn"
        echo "#"
    } > "$tmp"

    if [ "$master" = "1" ]; then
        : > "$dtmp"
        [ "$ads" = "1" ]      && [ -f "$LISTS/ads.txt" ]      && cat "$LISTS/ads.txt"      >> "$dtmp"
        [ "$gambling" = "1" ] && [ -f "$LISTS/gambling.txt" ] && cat "$LISTS/gambling.txt" >> "$dtmp"
        [ "$porn" = "1" ]     && [ -f "$LISTS/porn.txt" ]     && cat "$LISTS/porn.txt"     >> "$dtmp"
        # de-duplicate across the enabled lists, then prefix with 0.0.0.0
        awk 'NF && !seen[$1]++ { print "0.0.0.0 " $1 }' "$dtmp" >> "$tmp"
        rm -f "$dtmp"
    fi

    chmod 644 "$tmp"
    mv -f "$tmp" "$HOSTS"
    log "built hosts: $(count_blocked) domains (master=$master ads=$ads gambling=$gambling porn=$porn)"
}

count_blocked() {
    if [ -f "$HOSTS" ]; then
        grep -c '^0\.0\.0\.0 ' "$HOSTS" 2>/dev/null
    else
        echo 0
    fi
}

# ---------------------------------------------------------------------------
#  Bind-mount over the real hosts file
# ---------------------------------------------------------------------------
hosts_target() {
    if [ -e /system/etc/hosts ]; then
        echo /system/etc/hosts
    else
        echo /etc/hosts
    fi
}

# Is our hosts file currently bind-mounted over the real one?
# A file bind-mount shows up as its own mount point in the mount tables;
# its "source" field is the underlying device, NOT our path, so we must
# match on the mount point (or compare inodes).
is_mounted() {
    tgt=$(hosts_target)
    if [ -r /proc/self/mountinfo ]; then
        awk -v t="$tgt" '$5 == t { f=1 } END { exit !f }' /proc/self/mountinfo 2>/dev/null && return 0
    fi
    if [ -r /proc/mounts ]; then
        awk -v t="$tgt" '$2 == t { f=1 } END { exit !f }' /proc/mounts 2>/dev/null && return 0
    fi
    # last resort: if the mount point IS our file, the inodes match
    a=$(stat -c %i "$tgt" 2>/dev/null)
    b=$(stat -c %i "$HOSTS" 2>/dev/null)
    [ -n "$a" ] && [ "$a" = "$b" ] && return 0
    return 1
}

# What the resolver actually sees: how many blocked entries are live in the
# real hosts file right now.
live_blocked() {
    grep -c '^0\.0\.0\.0 ' "$(hosts_target)" 2>/dev/null
}

busyboxes() {
    for bb in /data/adb/magisk/busybox /data/adb/ksu/bin/busybox /data/adb/ap/bin/busybox /system/bin/busybox; do
        [ -x "$bb" ] && echo "$bb"
    done
}

hosts_context() {
    c=""
    for bb in $(busyboxes); do
        c=$("$bb" ls -Zd "$HOSTS" 2>/dev/null | awk '{print $1}')
        [ -n "$c" ] && break
    done
    if [ -z "$c" ] && command -v ls >/dev/null 2>&1; then
        c=$(ls -Zd "$HOSTS" 2>/dev/null | awk '{print $1}')
    fi
    echo "$c"
}

# netd (the DNS resolver) is denied read on files labelled adb_data_file,
# which is what everything under /data/adb gets.  If our hosts file still
# carries that label, blocking silently does nothing.
label_ok() {
    ctx=$(hosts_context)
    case "$ctx" in
        "") return 0 ;;              # cannot tell - do not cry wolf
        *adb_data_file*) return 1 ;;
        *) return 0 ;;
    esac
}

# A bind mount keeps the *source* file's SELinux label.  Clone the label of
# the real hosts file (system_file) onto ours so netd is allowed to read it.
fix_hosts_label() {
    ref="$1"
    [ -e "$ref" ] || ref=/system/etc/hosts

    for bb in $(busyboxes); do
        if "$bb" chcon --reference="$ref" "$HOSTS" 2>/dev/null; then
            log "relabel: cloned context of $ref"
            return 0
        fi
        if "$bb" chcon u:object_r:system_file:s0 "$HOSTS" 2>/dev/null; then
            log "relabel: set system_file"
            return 0
        fi
    done
    if command -v chcon >/dev/null 2>&1; then
        if chcon --reference="$ref" "$HOSTS" 2>/dev/null; then
            log "relabel: cloned context of $ref (toybox)"
            return 0
        fi
        if chcon u:object_r:system_file:s0 "$HOSTS" 2>/dev/null; then
            log "relabel: set system_file (toybox)"
            return 0
        fi
    fi
    log "relabel: FAILED - netd may not be able to read the hosts file"
    return 1
}

mount_hosts() {
    [ -f "$HOSTS" ] || return 1
    tgt=$(hosts_target)

    # relabel BEFORE mounting - the mount keeps the source file's label
    fix_hosts_label "$tgt"

    # drop any previous Guardian mount so we don't stack them
    umount "$tgt" 2>/dev/null

    if mount -o bind "$HOSTS" "$tgt" 2>/dev/null; then
        log "mounted $HOSTS -> $tgt"
    elif mount --bind "$HOSTS" "$tgt" 2>/dev/null; then
        log "mounted (--bind) $HOSTS -> $tgt"
    else
        log "ERROR: failed to bind-mount $HOSTS -> $tgt"
        return 1
    fi
    log "hosts context: $(hosts_context)"
    flush_dns
    return 0
}

flush_dns() {
    # best-effort; new lookups pick up the new file immediately
    for c in "ndc resolver flushdefaultif" "ndc resolver clearnetdns 0" "ndc resolver flushnet 0"; do
        $c >/dev/null 2>&1
    done
}

# ---------------------------------------------------------------------------
#  Set one toggle, rebuild + remount
# ---------------------------------------------------------------------------
set_conf() {
    key="$1"; val="$2"
    case "$key" in master|ads|gambling|porn) ;; *) return 1;; esac
    case "$val" in 0|1) ;; *) return 1;; esac

    ensure_data
    load_conf
    eval "$key=\$val"
    save_conf
    build_hosts
    mount_hosts
}

list_updated() {
    if [ -f "$STAMP" ]; then cat "$STAMP" 2>/dev/null; else echo "-"; fi
}

stamp_now() {
    date '+%Y-%m-%d' > "$STAMP" 2>/dev/null
    date '+%s' > "$STAMP.epoch" 2>/dev/null
}

# ---------------------------------------------------------------------------
#  Status as JSON (single line, last line of stdout)
# ---------------------------------------------------------------------------
status_json() {
    load_conf
    blocked=$(count_blocked)
    if is_mounted; then mounted=true; else mounted=false; fi
    ctx=$(hosts_context)

    live=$(live_blocked)
    case "$live" in ''|*[!0-9]*) live=0;; esac

    # "active" means the resolver can actually see blocked entries:
    # the file must be mounted (live entries) AND readable by netd (label).
    active=false
    warn=""
    if [ "$master" = "1" ]; then
        if [ "$live" -le 100 ]; then
            warn="Blocking is off - the hosts file is not mounted"
        elif ! label_ok; then
            warn="Blocking is off - SELinux is stopping the DNS resolver"
        else
            active=true
        fi
    fi

    printf '{"master":%s,"ads":%s,"gambling":%s,"porn":%s,"blocked":%s,"live":%s,"active":%s,"mounted":%s,"context":"%s","warn":"%s","updated":"%s"}\n' \
        "$master" "$ads" "$gambling" "$porn" "$blocked" "$live" "$active" "$mounted" "$ctx" "$warn" "$(list_updated)"
}
