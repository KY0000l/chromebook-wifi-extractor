#!/usr/bin/env bash
set -euo pipefail

OUT="/tmp/wifi_export.tsv"
TMPAGG="/tmp/shill.profile.$$.tmp"
TMPENC="/tmp/enc.$$.tmp"

cleanup() {
  rm -f "$TMPAGG" "$TMPENC"
}
trap cleanup EXIT

if [ "$(id -u)" -ne 0 ]; then
  echo "error: run as root (sudo)."
  exit 1
fi

echo "searching for shill.profile files..."
mapfile -t found < <(find /home /var /var/lib 2>/dev/null -type f -name shill.profile || true)

if [ "${#found[@]}" -eq 0 ]; then
  echo "no shill.profile files found. are you in developer mode?"
  exit 2
fi

: > "$TMPAGG"
for p in "${found[@]}"; do
  echo "### FROM: $p" >> "$TMPAGG"
  cat "$p" >> "$TMPAGG"
  echo "" >> "$TMPAGG"
done
chmod 600 "$TMPAGG"

: > "$OUT"
ssid=""
while IFS= read -r line; do
  # trim leading/trailing whitespace
  case "$line" in
    Name=*)
      ssid="${line#Name=}"
      ;;
    Passphrase=rot47:*)
      enc="${line#Passphrase=rot47:}"
      # store encoded safely to a temp file then decode with tr (rot47)
      printf '%s' "$enc" > "$TMPENC"
      if dec="$(tr '!-~' 'P-~!-O' < "$TMPENC" 2>/dev/null)"; then
        printf '%s\t%s\n' "$ssid" "$dec" >> "$OUT"
      else
        printf '%s\t%s\n' "$ssid" "<<<decode-failed>>>" >> "$OUT"
      fi
      ;;
    *)
      # ignore other lines
      ;;
  esac
done < "$TMPAGG"

chmod 600 "$OUT"
echo "done. exported to: $OUT"
echo "----"
cat "$OUT"
echo "----"
echo "copy /tmp/wifi_export.tsv off the device if you need it."
