# shellcheck shell=bash
# _pubkey.sh — validate + persist an OpenSSH-format public key blob.
#
# Sourced by bootstrap.sh. Pure functions, no top-level side effects.
#
# Public API:
#   pubkey_validate     <blob>                       → 0/1, stderr on error
#   pubkey_fingerprint  <pub-file-path>              → prints "SHA256:…"
#   pubkey_write        <blob> <dest-path>           → writes (atomic) + chmods 644
#   pubkey_read_content <pub-file-path>              → prints first line of file

# Reject anything that isn't a single-line ssh-ed25519 OpenSSH public key.
# We intentionally accept ONLY ed25519 — matches the plan and 1Password's default.
pubkey_validate() {
	local blob="$1"
	if [[ -z "$blob" ]]; then
		echo "[pubkey] ERROR: empty public-key blob" >&2
		return 1
	fi
	# Must start with "ssh-ed25519 AAAA" and have no embedded newlines.
	if [[ "$blob" == *$'\n'* ]]; then
		echo "[pubkey] ERROR: public key must be a single line" >&2
		return 1
	fi
	if [[ "$blob" != "ssh-ed25519 AAAA"* ]]; then
		echo "[pubkey] ERROR: expected an ssh-ed25519 public key (got: ${blob:0:32}…)" >&2
		return 1
	fi
	# Must have at least 2 space-separated fields (type + base64 body).
	local fields
	# shellcheck disable=SC2206
	fields=( $blob )
	if (( ${#fields[@]} < 2 )); then
		echo "[pubkey] ERROR: malformed public key (need 'ssh-ed25519 <base64> [comment]')" >&2
		return 1
	fi
	return 0
}

pubkey_fingerprint() {
	local path="$1"
	if [[ ! -r "$path" ]]; then
		echo "[pubkey] ERROR: cannot read $path" >&2
		return 1
	fi
	# ssh-keygen -lf prints "<bits> SHA256:<hash> <comment> (ED25519)"
	local out
	if ! out="$(ssh-keygen -lf "$path" 2>&1)"; then
		echo "[pubkey] ERROR: ssh-keygen failed on $path: $out" >&2
		return 1
	fi
	# Extract the SHA256:… token.
	awk '{for(i=1;i<=NF;i++) if ($i ~ /^SHA256:/) {print $i; exit}}' <<<"$out"
}

# Atomic write: write to a temp file in the same dir, then rename.
pubkey_write() {
	local blob="$1" dest="$2"
	if ! pubkey_validate "$blob"; then
		return 1
	fi
	local dir
	dir="$(dirname -- "$dest")"
	if [[ ! -d "$dir" ]]; then
		mkdir -p "$dir" || return 1
		chmod 700 "$dir" 2>/dev/null || true
	fi
	local tmp
	tmp="$(mktemp "${dest}.XXXXXX")" || return 1
	# Ensure a trailing newline.
	printf '%s\n' "$blob" >"$tmp" || { rm -f "$tmp"; return 1; }
	chmod 644 "$tmp" || { rm -f "$tmp"; return 1; }
	mv -f "$tmp" "$dest" || { rm -f "$tmp"; return 1; }
	# Parse-check the written file — refuse anything ssh-keygen can't read.
	if ! ssh-keygen -lf "$dest" >/dev/null 2>&1; then
		echo "[pubkey] ERROR: ssh-keygen refused the written key at $dest" >&2
		rm -f "$dest"
		return 1
	fi
	return 0
}

pubkey_read_content() {
	local path="$1"
	if [[ ! -r "$path" ]]; then
		echo "[pubkey] ERROR: cannot read $path" >&2
		return 1
	fi
	# First non-empty line (defensive against trailing blanks).
	awk 'NF {print; exit}' "$path"
}
