#!/system/bin/sh
# Guardian - runs very early, before the network stack starts, so the
# hosts file is already in place for the first DNS lookup after boot.

MODDIR=${0%/*}
. "$MODDIR/scripts/common.sh"

ensure_data

if needs_build; then
    build_hosts
fi

mount_hosts
