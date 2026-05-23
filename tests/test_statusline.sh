#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

tmpdir=$(make_tmpdir)
json1='{"context_window":{"current_usage":{"input_tokens":10},"context_window_size":100},"rate_limits":{"five_hour":{"used_percentage":12,"resets_at":2000000000},"seven_day":{"used_percentage":34,"resets_at":2000003600}}}'
json2='{"context_window":{"current_usage":{"input_tokens":20},"context_window_size":100}}'
json_high='{"context_window":{"current_usage":{"input_tokens":30},"context_window_size":100},"rate_limits":{"five_hour":{"used_percentage":61,"resets_at":2000000000},"seven_day":{"used_percentage":63,"resets_at":2000003600}}}'
json_low='{"context_window":{"current_usage":{"input_tokens":40},"context_window_size":100},"rate_limits":{"five_hour":{"used_percentage":1,"resets_at":2000000000},"seven_day":{"used_percentage":61,"resets_at":2000003600}}}'

printf '%s' "$json1" | HOME="$tmpdir" bash "$ROOT/scripts/statusline.sh" >/dev/null
printf '%s' "$json2" | HOME="$tmpdir" bash "$ROOT/scripts/statusline.sh" >"$tmpdir/out2"
printf '%s' "$json2" | HOME="$tmpdir" bash "$ROOT/scripts/statusline.sh" >"$tmpdir/out3"
grep -q '"used_percentage": 12' "$tmpdir/.cache/waza-statusline/last.json"
printf '%s' "$json_high" | HOME="$tmpdir" bash "$ROOT/scripts/statusline.sh" >/dev/null
printf '%s' "$json_low" | HOME="$tmpdir" bash "$ROOT/scripts/statusline.sh" >"$tmpdir/out4"
grep -q '5h:' "$tmpdir/out2"
grep -q '7d:' "$tmpdir/out2"
grep -q '12%' "$tmpdir/out2"
grep -q '34%' "$tmpdir/out3"
grep -q '61%' "$tmpdir/out4"
grep -q '63%' "$tmpdir/out4"

# Existing high-water mark survives a fresh session with lower live values.
tmpdir2=$(make_tmpdir)
mkdir -p "$tmpdir2/.cache/waza-statusline"
printf '%s\n' '{"seven_day":{"used_percentage":63,"resets_at":2000003600}}' > "$tmpdir2/.cache/waza-statusline/highwater.json"
printf '%s' "$json1" | HOME="$tmpdir2" bash "$ROOT/scripts/statusline.sh" >"$tmpdir2/out"
grep -q '12%' "$tmpdir2/out"
grep -q '63%' "$tmpdir2/out"

echo "statusline smoke: ok"
