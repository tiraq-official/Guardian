#!/usr/bin/env python3
"""
fetch_lists.py - build Guardian's per-category blocklists.

Downloads every upstream source, normalises each to a plain domain list
(one domain per line), deduplicates, and writes:

    module/lists/ads.txt
    module/lists/gambling.txt
    module/lists/porn.txt

These files are committed to the repo and shipped inside the flashable
zip, so the module works fully offline right after flashing.

Source formats understood:
    domains  -> one bare domain per line (hagezi *-onlydomains.txt)
    hosts    -> "0.0.0.0 example.com" / "127.0.0.1 example.com"
    adblock  -> "||example.com^" (AdGuard/uBlock syntax)

Run:  python3 tools/fetch_lists.py
"""

import json
import os
import re
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "module", "lists")
UA = "Guardian-Blocklist-Builder/1.0 (+https://github.com/)"

HAGEZI = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard"

# Category -> list of (source-name, url, format)
SOURCES = {
    "ads": [
        ("hagezi-pro.plus", f"{HAGEZI}/pro.plus-onlydomains.txt", "domains"),
        ("stevenblack", "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts", "hosts"),
        ("adguard-sdns", "https://raw.githubusercontent.com/AdguardTeam/AdGuardSDNSFilter/master/Filters/rules.txt", "adblock"),
    ],
    "gambling": [
        ("hagezi-gambling", f"{HAGEZI}/gambling.mini-onlydomains.txt", "domains"),
    ],
    "porn": [
        ("hagezi-nsfw", f"{HAGEZI}/nsfw-onlydomains.txt", "domains"),
    ],
}

# Optional sources the user asked about. Enable by moving them into SOURCES.
# EnergizedProtection / AdGuard's published filter were unreachable from the
# build sandbox; Re-Malwack's hosts-update branch no longer exists.
OPTIONAL = {
    "ads": [
        # Adds ~134k extra unique domains, but roughly doubles the ads list.
        ("1hosts-lite", "https://raw.githubusercontent.com/badmojr/1Hosts/master/Lite/hosts.txt", "hosts"),
        ("1hosts-pro", "https://raw.githubusercontent.com/badmojr/1Hosts/master/Pro/hosts.txt", "hosts"),
        ("energized-spark", "https://block.energized.pro/spark/formats/hosts.txt", "hosts"),
        ("energized-unified", "https://block.energized.pro/unified/formats/hosts.txt", "hosts"),
        ("adguard-published", "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt", "adblock"),
    ],
}

DOMAIN_RE = re.compile(r"^(?=.{1,253}$)([a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$")
# things we never want to block
SKIP = {"localhost", "localhost.localdomain", "local", "broadcasthost", "ip6-localhost", "ip6-loopback"}
# a few hosts-file placeholders / TLDs that show up in aggregate lists
SKIP_SUFFIX = (".local", ".localhost", ".onion", ".test", ".invalid", ".example")


def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=90) as r:
        return r.read().decode("utf-8", "ignore")


def parse(text: str, fmt: str) -> set:
    out = set()
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line[0] in "#!":
            continue
        if fmt == "domains":
            tok = line.split()[0]
        elif fmt == "hosts":
            parts = line.split()
            if len(parts) < 2:
                continue
            tok = parts[1]
        elif fmt == "adblock":
            m = re.match(r"^\|\|([^/^$|]+)", line)
            if not m:
                continue
            tok = m.group(1)
        else:
            continue
        tok = tok.strip().strip(".").lower()
        if not tok or tok in SKIP or tok.endswith(SKIP_SUFFIX):
            continue
        if DOMAIN_RE.match(tok):
            out.add(tok)
    return out


def build_category(cat: str, sources: list) -> set:
    merged = set()
    for name, url, fmt in sources:
        try:
            text = fetch(url)
            got = parse(text, fmt)
            merged |= got
            print(f"  [{cat}] {name:<18} {len(got):>8,} domains", file=sys.stderr)
        except Exception as e:  # noqa: BLE001
            print(f"  [{cat}] {name:<18} FAILED: {e}", file=sys.stderr)
    return merged


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    meta = {"generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "categories": {}}

    for cat, sources in SOURCES.items():
        print(f"Building '{cat}' ...", file=sys.stderr)
        domains = build_category(cat, sources)
        if not domains:
            print(f"ERROR: category '{cat}' came back empty", file=sys.stderr)
            return 1
        path = os.path.join(OUT, f"{cat}.txt")
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(sorted(domains)))
            f.write("\n")
        meta["categories"][cat] = {
            "count": len(domains),
            "sources": [s[0] for s in sources],
        }
        print(f"  -> {path}  ({len(domains):,} unique domains)", file=sys.stderr)

    with open(os.path.join(OUT, "meta.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)
    print(json.dumps(meta, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
