# Changelog

## v1.0.0

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
