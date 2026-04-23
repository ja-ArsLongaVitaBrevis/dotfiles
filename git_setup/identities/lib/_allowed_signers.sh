# shellcheck shell=bash
# _allowed_signers.sh — manage lines in ~/.ssh/allowed_signers.
#
# File format (one line per signer):
#   <email> ssh-ed25519 <base64-body> [comment]
#
# The email is treated as the unique key. Upsert replaces the line for a
# given email in place; remove deletes it. Other signers' lines are left
# untouched, and a trailing newline is preserved.
#
# Public API:
#   allowed_signers_upsert <file> <email> <pub-blob>
#   allowed_signers_remove <file> <email>

_as_atomic_write() {
	local dest="$1" content="$2" mode="${3:-600}"
	local dir
	dir="$(dirname -- "$dest")"
	[[ -d "$dir" ]] || { mkdir -p "$dir" && chmod 700 "$dir" 2>/dev/null || true; }
	local tmp
	tmp="$(mktemp "${dest}.XXXXXX")" || return 1
	printf '%s' "$content" >"$tmp" || { rm -f "$tmp"; return 1; }
	chmod "$mode" "$tmp" || { rm -f "$tmp"; return 1; }
	mv -f "$tmp" "$dest"
}

allowed_signers_upsert() {
	local file="$1" email="$2" blob="$3"
	if [[ -z "$email" || -z "$blob" ]]; then
		echo "[allowed_signers] ERROR: email and public key blob required" >&2
		return 1
	fi
	if [[ "$blob" == *$'\n'* ]]; then
		echo "[allowed_signers] ERROR: public key blob must be single-line" >&2
		return 1
	fi

	local new_line="${email} ${blob}"

	if [[ ! -e "$file" ]]; then
		_as_atomic_write "$file" "${new_line}"$'\n' 600
		return
	fi

	# Rewrite: keep every line whose first field != email, then append ours.
	local rewritten
	rewritten="$(
		awk -v email="$email" '
			NF == 0 { print; next }
			{
				if ($1 == email) next
				print
			}
		' "$file"
	)"

	# Trim trailing blank lines for a clean append.
	rewritten="$(printf '%s\n' "$rewritten" | awk '
		{ lines[NR] = $0 }
		END {
			last = NR
			while (last > 0 && lines[last] == "") last--
			for (i = 1; i <= last; i++) print lines[i]
		}
	')"

	local out
	if [[ -z "$rewritten" ]]; then
		out="${new_line}"$'\n'
	else
		out="${rewritten}"$'\n'"${new_line}"$'\n'
	fi

	local mode=600
	if command -v stat >/dev/null 2>&1; then
		local m
		m="$(stat -f '%Lp' "$file" 2>/dev/null || stat -c '%a' "$file" 2>/dev/null)"
		[[ -n "$m" ]] && mode="$m"
	fi
	_as_atomic_write "$file" "$out" "$mode"
}

allowed_signers_remove() {
	local file="$1" email="$2"
	[[ -e "$file" ]] || return 0
	local rewritten
	rewritten="$(
		awk -v email="$email" '
			NF == 0 { print; next }
			{
				if ($1 == email) next
				print
			}
		' "$file"
	)"
	rewritten="$(printf '%s\n' "$rewritten" | awk '
		{ lines[NR] = $0 }
		END {
			last = NR
			while (last > 0 && lines[last] == "") last--
			for (i = 1; i <= last; i++) print lines[i]
		}
	')"

	local mode=600
	if command -v stat >/dev/null 2>&1; then
		local m
		m="$(stat -f '%Lp' "$file" 2>/dev/null || stat -c '%a' "$file" 2>/dev/null)"
		[[ -n "$m" ]] && mode="$m"
	fi

	if [[ -n "$rewritten" ]]; then
		_as_atomic_write "$file" "${rewritten}"$'\n' "$mode"
	else
		_as_atomic_write "$file" "" "$mode"
	fi
}
