# Changelog

## v2.0

Redesigned WebUI.

- New layout: a large **Protection** card with a switch, a **What to block**
  section with a **Block all** card, and a grid of **Gaming**, **Ads &
  trackers** and **Adult / NSFW** cards.
- **Block all** is derived — it fills in when all three are on and clears the
  moment one is off. Tapping it sets or clears all three at once.
- While protection is off, the block cards render as disabled settings.
- Selected cards fill with the system accent; everything stays Material You
  and light/dark aware.
- Backend: `set` now accepts multiple `key value` pairs, so "Block all"
  rebuilds and remounts the hosts file only once.

## v1.0

First release.

- Flashable module for Magisk, KernelSU / KernelSU-Next, APatch, FolkPatch and
  SukiSU Ultra.
- Master switch plus independent **Ads & trackers**, **Gambling** and
  **Adult / NSFW** toggles.
- Material 3 Expressive WebUI: dynamic (Material You) colour, automatic
  light/dark, springy switches, count-up stats, staggered entrance animation.
- ~500,000 domains bundled, built from HaGeZi Pro.plus / Gambling / NSFW,
  StevenBlack and the AdGuard DNS filter.
- Instant re-mount when a toggle changes; no reboot required.
- Relabels the hosts file to `system_file` before mounting, so the DNS
  resolver is actually allowed to read it (plus a `sepolicy.rule` fallback).
- WebUI warns when blocking is not active, and `scripts/diagnose.sh` reports
  the mount state, SELinux context and any resolver denials.
- One-tap blocklist update from the WebUI, plus optional weekly auto-update.
- Action button toggles the master switch on managers without a WebUI.
