#!/usr/bin/env bash
set -euo pipefail

OUT="/tmp/wifi_export.tsv"
TMP="/tmp/shill.profile.$$.tmp"

cleanup() {
  rm -f "$TMP"
}
trap cleanup EXIT

# must be root
if [ "$(id -u)" -ne 0 ]; then
  echo "error: script must be run as root (use sudo)."
  exit 1
fi

echo "looking for shill.profile files (may need developer mode)..."

# search common locations for shill.profile
# include /home, /home/root, /var, /var/lib, also check /home/*/home/* pattern used by some chromeos versions
mapfile -t found < <(find /home /var /var/lib 2>/dev/null -type f -name shill.profile || true)

if [ "${#found[@]}" -eq 0 ]; then
  echo "no shill.profile files found. are you in developer mode and running on Chrome OS? (developer mode is required on stock Chrome OS to access these files)"
  exit 2
fi

# concatenate into temp (with header comments)
: > "$TMP"
for p in "${found[@]}"; do
  echo "### FROM: $p" >> "$TMP"
  cat "$p" >> "$TMP"
  echo "" >> "$TMP"
done
chmod 600 "$TMP"

echo "decoding rot47 passphrases and extracting SSIDs..."

# AWK: capture Name= as SSID, find Passphrase=rot47:<enc> and decode with tr (rot47)
awk '
  /Name=/ { ssid = substr($0, index($0,"=")+1) }
  /Passphrase=rot47:/ {
    enc = substr($0, index($0,":")+1)
    # use tr to do rot47: map printable ASCII range 33-126
    cmd = "echo \"" enc "\" | tr \"!-~\" \"P-~!-O\""
    cmd | getline dec
    close(cmd)
    # print SSID and decoded passphrase, tab-separated
    print ssid "\t" dec
  }
' "$TMP" > "$OUT" || { echo "failed to produce $OUT"; exit 3; }

chmod 600 "$OUT"
echo "done. exported SSID<TAB>Password to: $OUT"
echo "----"
cat "$OUT"
echo "----"
echo "you can copy /tmp/wifi_export.tsv to a safe location. remove it when done."
