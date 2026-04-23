# shellcheck shell=bash
# _fenced_block.sh — idempotent fenced-block upsert / remove for text files.
#
# A "fenced block" is a contiguous region delimited by two marker lines:
#   # >>> <tag> >>>
#   ...content...
#   # <<< <tag> <<<
#
# Re-running upsert with the same tag REPLACES the block in place.
# If no block with that tag exists, it's APPENDED to the file.
#
# Public API:
#   fenced_upsert <file> <tag> <content>   → replace-or-append
#   fenced_remove <file> <tag>             → delete block (and its blank line padding)
#   fenced_has    <file> <tag>             → 0 if block exists, 1 otherwise
#
# <content> is passed as a single string (may contain newlines).

# Single-line markers — DO NOT add trailing newlines here; callers insert
# newlines where they need them. This avoids the $(…) command-substitution
# trailing-newline-stripping footgun.
_fenced_open_line()  { printf '# >>> %s >>>'  "$1"; }
_fenced_close_line() { printf '# <<< %s <<<'  "$1"; }

fenced_has() {
	local file="$1" tag="$2"
	[[ -r "$file" ]] || return 1
	grep -qxF "$(_fenced_open_line "$tag")" "$file"
}

# Write to a temp file then atomically rename. Creates parent dir if needed.
_fenced_atomic_write() {
	local dest="$1" content="$2" mode="${3:-600}"
	local dir
	dir="$(dirname -- "$dest")"
	[[ -d "$dir" ]] || mkdir -p "$dir"
	local tmp
	tmp="$(mktemp "${dest}.XXXXXX")" || return 1
	printf '%s' "$content" >"$tmp" || { rm -f "$tmp"; return 1; }
	chmod "$mode" "$tmp" || { rm -f "$tmp"; return 1; }
	mv -f "$tmp" "$dest"
}

# fenced_upsert <file> <tag> <content> [<mode>]
#   mode defaults to 600 when creating a new file; if the file exists we keep
#   its current permissions.
fenced_upsert() {
	local file="$1" tag="$2" content="$3" mode="${4:-600}"
	local open_line close_line
	open_line="$(_fenced_open_line  "$tag")"
	close_line="$(_fenced_close_line "$tag")"

	# Ensure content ends with exactly one newline.
	[[ "$content" == *$'\n' ]] || content="${content}"$'\n'
	# Explicitly punctuate with $'\n' so command-substitution stripping
	# can't eat a newline between marker and content.
	local block="${open_line}"$'\n'"${content}${close_line}"$'\n'

	if [[ ! -e "$file" ]]; then
		# New file: write header comment + block.
		_fenced_atomic_write "$file" "$block" "$mode"
		return
	fi

	# Preserve existing mode when rewriting.
	if command -v stat >/dev/null 2>&1; then
		local existing_mode
		existing_mode="$(stat -f '%Lp' "$file" 2>/dev/null || stat -c '%a' "$file" 2>/dev/null)"
		[[ -n "$existing_mode" ]] && mode="$existing_mode"
	fi

	local existing
	existing="$(cat "$file")"

	# awk-based surgery: delete existing block, then we'll re-append.
	# Match marker lines by exact tag to avoid collisions with other blocks.
	local stripped
	stripped="$(
		awk -v open_marker="$open_line" -v close_marker="$close_line" '
			BEGIN { in_block = 0 }
			{
				if (in_block) {
					if ($0 == close_marker) { in_block = 0 }
					next
				}
				if ($0 == open_marker) { in_block = 1; next }
				print
			}
		' <<<"$existing"
	)"

	# Normalise: collapse trailing blank lines to a single newline.
	# Then append the fresh block separated by one blank line.
	stripped="$(printf '%s\n' "$stripped" | awk '
		{ lines[NR] = $0 }
		END {
			last = NR
			while (last > 0 && lines[last] == "") last--
			for (i = 1; i <= last; i++) print lines[i]
		}
	')"

	local new
	if [[ -z "$stripped" ]]; then
		new="${block}"
	else
		new="${stripped}"$'\n\n'"${block}"
	fi
	_fenced_atomic_write "$file" "$new" "$mode"
}

fenced_remove() {
	local file="$1" tag="$2"
	[[ -e "$file" ]] || return 0
	local open_line close_line
	open_line="$(_fenced_open_line  "$tag")"
	close_line="$(_fenced_close_line "$tag")"

	local existing
	existing="$(cat "$file")"

	local stripped
	stripped="$(
		awk -v open_marker="$open_line" -v close_marker="$close_line" '
			BEGIN { in_block = 0 }
			{
				if (in_block) {
					if ($0 == close_marker) { in_block = 0 }
					next
				}
				if ($0 == open_marker) { in_block = 1; next }
				print
			}
		' <<<"$existing"
	)"

	# Trim trailing blank lines.
	stripped="$(printf '%s\n' "$stripped" | awk '
		{ lines[NR] = $0 }
		END {
			last = NR
			while (last > 0 && lines[last] == "") last--
			for (i = 1; i <= last; i++) print lines[i]
		}
	')"

	local mode=600
	if command -v stat >/dev/null 2>&1; then
		local existing_mode
		existing_mode="$(stat -f '%Lp' "$file" 2>/dev/null || stat -c '%a' "$file" 2>/dev/null)"
		[[ -n "$existing_mode" ]] && mode="$existing_mode"
	fi

	# Preserve a trailing newline if the result is non-empty.
	if [[ -n "$stripped" ]]; then
		_fenced_atomic_write "$file" "${stripped}"$'\n' "$mode"
	else
		_fenced_atomic_write "$file" "" "$mode"
	fi
}
