#!/usr/bin/env bash
# ── Config ────────────────────────────────────────────────────────────────
MAX_TITLE=40
MAX_ARTIST=28
MAX_ALBUM=32
CURL_TIMEOUT=6
CACHE_DIR="$HOME/.cache/quickshell/music"
mkdir -p "$CACHE_DIR"

# Keep cache tidy — drop oldest files beyond 30
find "$CACHE_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.gif" \) \
    -printf '%T@ %p\n' 2>/dev/null | sort -rn | tail -n +31 | \
    cut -d' ' -f2- | xargs -r rm -- 2>/dev/null

# ── Helpers ───────────────────────────────────────────────────────────────

format_time() {
    local s=${1:-0}
    # strip non-digits / floats from playerctl position output
    s=$(printf '%.0f' "$s" 2>/dev/null || echo 0)
    [[ $s -le 0 ]] && { echo "0:00"; return; }
    local h=$(( s / 3600 ))
    local m=$(( (s % 3600) / 60 ))
    local sec=$(( s % 60 ))
    if [[ $h -gt 0 ]]; then
        printf "%d:%02d:%02d" "$h" "$m" "$sec"
    else
        printf "%d:%02d" "$m" "$sec"
    fi
}

truncate() {
    local str="$1" max="$2"
    if [[ ${#str} -gt $max ]]; then
        echo "${str:0:$(( max - 1 ))}…"
    else
        echo "$str"
    fi
}

# Safe JSON string — escapes backslash, quote, and the common control chars
json_str() {
    local v="$1"
    v="${v//\\/\\\\}"    # backslash first
    v="${v//\"/\\\"}"    # double-quote
    v="${v//	/\\t}"     # tab
    printf '%s' "$v"
}

# Resolve and cache cover art; prints absolute file path or ""
resolve_cover() {
    local url
    url=$(playerctl metadata mpris:artUrl 2>/dev/null)
    [[ -z "$url" ]] && return

    # Local file:// URI — decode percent-encoding and return the path directly
    if [[ "$url" == file://* ]]; then
        local path
        path=$(python3 -c \
            "import sys,urllib.parse; print(urllib.parse.unquote(sys.argv[1]))" \
            "${url#file://}" 2>/dev/null)
        [[ -f "$path" ]] && echo "$path"
        return
    fi

    # Remote URL — hash-cache it
    local hash ext url_no_qs cached
    hash=$(printf '%s' "$url" | md5sum | awk '{print $1}')
    url_no_qs="${url%%\?*}"
    ext="${url_no_qs##*.}"
    # Sanity-check extension
    [[ -z "$ext" || "$ext" == "$url_no_qs" || ${#ext} -gt 4 ]] && ext="jpg"
    ext="${ext,,}"
    cached="$CACHE_DIR/${hash}.${ext}"

    if [[ -f "$cached" && -s "$cached" ]]; then
        echo "$cached"
        return
    fi

    if curl -s -L --max-time "$CURL_TIMEOUT" \
            -H "User-Agent: Mozilla/5.0" \
            -o "$cached" "$url" 2>/dev/null && [[ -s "$cached" ]]; then
        echo "$cached"
    else
        rm -f "$cached"
    fi
}

# ── Fallback JSON (nothing playing) ──────────────────────────────────────

no_player_json() {
    printf '{"title":"Not Playing","artist":"","album":"","status":"Stopped","position_seconds":0,"length_seconds":0,"progress":0,"position_str":"0:00","length_str":"0:00","cover":"","player":""}\n'
}

# ── Guards ────────────────────────────────────────────────────────────────

if ! command -v playerctl &>/dev/null; then
    no_player_json; exit 0
fi

# Pick the first active player (prefer Playing over Paused)
player=$(playerctl -l 2>/dev/null | head -n 1)
[[ -z "$player" ]] && { no_player_json; exit 0; }

# Check status with that player
status_raw=$(playerctl --player="$player" status 2>/dev/null)
[[ -z "$status_raw" || "$status_raw" == "No players found" ]] && { no_player_json; exit 0; }

# ── Cover-only mode (called from a separate slower timer if needed) ───────

if [[ "$1" == "cover" ]]; then
    resolve_cover
    exit 0
fi

# ── Metadata ──────────────────────────────────────────────────────────────

title=$(playerctl  --player="$player" metadata title  2>/dev/null)
artist=$(playerctl --player="$player" metadata artist 2>/dev/null)
album=$(playerctl  --player="$player" metadata album  2>/dev/null)

[[ -z "$title" ]] && { no_player_json; exit 0; }

# Length: mpris:length is in microseconds
raw_len=$(playerctl --player="$player" metadata mpris:length 2>/dev/null || echo 0)
length_sec=$(( raw_len / 1000000 ))
[[ $length_sec -le 0 ]] && length_sec=0

# Position: playerctl position returns seconds as a float
pos_raw=$(playerctl --player="$player" position 2>/dev/null || echo 0)
position_sec=$(printf '%.0f' "${pos_raw:-0}" 2>/dev/null || echo 0)
[[ $position_sec -lt 0 ]] && position_sec=0
[[ $length_sec -gt 0 && $position_sec -gt $length_sec ]] && position_sec=$length_sec

# Progress
progress=0
[[ $length_sec -gt 0 ]] && progress=$(( position_sec * 100 / length_sec ))

# Cover art
cover=$(resolve_cover)

# Truncate display strings
t=$(truncate "$title"  $MAX_TITLE)
a=$(truncate "$artist" $MAX_ARTIST)
b=$(truncate "$album"  $MAX_ALBUM)

# ── JSON output ───────────────────────────────────────────────────────────

printf '{"title":"%s","artist":"%s","album":"%s","status":"%s","position_seconds":%d,"length_seconds":%d,"progress":%d,"position_str":"%s","length_str":"%s","cover":"%s","player":"%s"}\n' \
    "$(json_str "$t")" "$(json_str "$a")" "$(json_str "$b")" "$(json_str "$status_raw")" \
    "$position_sec" "$length_sec" "$progress" "$(format_time "$position_sec")" \
    "$(format_time "$length_sec")" "$(json_str "$cover")" "$(json_str "$player")"