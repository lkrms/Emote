#!/bin/bash

set -euo pipefail

[ ${BASH_VERSINFO[0]} -eq 4 ] && [ ${BASH_VERSINFO[1]} -ge 2 ] ||
    [ ${BASH_VERSINFO[0]} -gt 4 ] || {
    echo "Bash 4.2+ required" >&2
    exit 1
}

export LC_ALL=en_US.UTF-8

function format_json() {
    jq | awk '
/^[[:blank:]]*"keywords": \[$/ {
    line = $0
    next
}
line && /^[[:blank:]]*\],$/ {
    print line "],"
    line = ""
    next
    }
line {
    sub(/^[[:blank:]]*/, "")
    line = line (line ~ ",$" ? " " : "") $0
    next
}
! line {
    print
}'
}

_DIR=${BASH_SOURCE[0]%${BASH_SOURCE[0]##*/}}
_DIR=${_DIR:-.}
_FILE=${_DIR%/}/emojis.json

JSON=$(cat "$_FILE")

# Map emojis.json to:
#
#     grinning	😀	4	1F600
#     grimacing	😬	4	1F62C
#     grin	😁	4	1F601
#     ...
EMOJI=$(
    while IFS=$'\t' read -r KEY CHAR BYTES; do
        printf '%s\t%s\t%s\t%X\n' "$KEY" "$CHAR" "$BYTES" "'$CHAR'"
    done < <(jq -r \
        'to_entries[] |
    "\(.key)\t\(.value.char)\t\(.value.char | utf8bytelength)"' <<<"$JSON")
)

# Get the codepoint of each emoji represented by fewer than 4 UTF-8 bytes
CODEPOINTS=$(
    awk '$3 < 4 {print $4}' <<<"$EMOJI" | sort -u
)

# Replace each unqualified emoji with its qualified equivalent
i=0
# `echo` removes leading spaces on macOS
COUNT=$(echo $({ [ -z "${CODEPOINTS:+1}" ] || cat <<<"$CODEPOINTS"; } | wc -l))
for CODEPOINT in $CODEPOINTS; do
    eval "FROM=$'\u$CODEPOINT'"
    eval "TO=$'\u$CODEPOINT\uFE0F'"
    printf '%s of %s: %s -> %s (%s)\n' "$((++i))" \
        "$COUNT" "$FROM" "$TO" "$CODEPOINT" >&2
    JSON=${JSON//"$FROM"/$TO}
done

# Collapse each "keywords" array and output to emojis-fixed.json
format_json <<<"$JSON" >"${_DIR%/}/emojis-fixed.json"

# For comparison, format the original file too
format_json <"$_FILE" >"${_DIR%/}/emojis-formatted.json"

echo "Finished ($COUNT emoji fixed)" >&2
