#!/system/bin/sh
# Guardian - runs very early, before the network stack starts, so the
# hosts file is already in place for the first DNS lookup after boot.

MODDIR=${0%/*}
. "$MODDIR/scripts/common.sh"

ensure_data

# drop any redirect left over from the v3.x resolver engine
cleanup_resolver

if needs_build; then
    build_hosts
fi

mount_hosts
