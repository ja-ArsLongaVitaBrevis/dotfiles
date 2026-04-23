# shellcheck shell=bash
# identities.sh — runtime helpers for the multi-identity git setup.
# Sourced from .bash_profile. Function defs only — no subprocesses at load
# time (matches the repo's perf policy).
#
# See git_setup/identities/README.md for end-to-end docs.

# ---------------------------------------------------------------------------
# 1Password SSH agent wiring.
# If the 1Password agent socket exists and SSH_AUTH_SOCK isn't already set,
# point the shell at it. Single file test, no subprocess. Cheap.
# ---------------------------------------------------------------------------
_op_sock="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
if [[ -S "$_op_sock" && -z "${SSH_AUTH_SOCK:-}" ]]; then
	export SSH_AUTH_SOCK="$_op_sock"
fi
unset _op_sock

# Path to this module — used by helpers to find bootstrap.sh.
_identities_dir() {
	# BASH_SOURCE is set when this file is sourced (which is how .bash_profile
	# loads it). Fall back to $DOTFILES_DIR if somehow unset.
	local src="${BASH_SOURCE[0]:-}"
	if [[ -n "$src" ]]; then
		cd "$(dirname "$src")" 2>/dev/null && pwd -P
	elif [[ -n "${DOTFILES_DIR:-}" ]]; then
		printf '%s\n' "$DOTFILES_DIR/git_setup/identities"
	fi
}
IDENTITIES_DIR="$(_identities_dir)"
unset -f _identities_dir

# ---------------------------------------------------------------------------
# git_whoami — print the resolved identity for $PWD.
# Runs git itself, which walks [includeIf] at every call, so what you see
# is what git will actually use.
# ---------------------------------------------------------------------------
git_whoami() {
	if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		echo "[git_whoami] not inside a git repo ($PWD)" >&2
		return 1
	fi
	local name email signing_key ssh_cmd remote_url root
	name="$(git config user.name 2>/dev/null || true)"
	email="$(git config user.email 2>/dev/null || true)"
	signing_key="$(git config user.signingKey 2>/dev/null || true)"
	ssh_cmd="$(git config core.sshCommand 2>/dev/null || true)"
	remote_url="$(git config --get remote.origin.url 2>/dev/null || true)"
	root="$(git rev-parse --show-toplevel 2>/dev/null || true)"

	local red='' green='' yellow='' cyan='' reset=''
	if [[ -t 1 ]]; then
		red=$'\033[1;31m'; green=$'\033[1;32m'; yellow=$'\033[1;33m'
		cyan=$'\033[36m';  reset=$'\033[0m'
	fi

	local status="$green✓$reset"
	local warnings=()
	if [[ -z "$email" ]]; then
		status="$red✗$reset"
		warnings+=( "no user.email — is this repo outside a managed ~/Code<Id>/ root?" )
	fi
	if [[ -z "$signing_key" ]]; then
		warnings+=( "no user.signingKey — signed commits will fail" )
	fi
	if [[ -n "$remote_url" && "$remote_url" == git@github.com:* ]]; then
		warnings+=( "remote uses plain github.com — run 'git_identity_fix' to switch to the identity host alias" )
	fi

	printf '%s[git_whoami]%s %s %s\n' "$cyan" "$reset" "$status" "$root"
	printf '  user.name       %s\n' "${name:-<unset>}"
	printf '  user.email      %s\n' "${email:-<unset>}"
	printf '  user.signingKey %s\n' "${signing_key:-<unset>}"
	printf '  core.sshCommand %s\n' "${ssh_cmd:-<unset>}"
	printf '  remote.origin   %s\n' "${remote_url:-<unset>}"

	# Guard for empty array under `set -u` (macOS bash 3.2 is strict).
	if (( ${#warnings[@]} > 0 )); then
		local w
		for w in "${warnings[@]}"; do
			printf '  %s!%s %s\n' "$yellow" "$reset" "$w"
		done
	fi

	# Return nonzero if anything is missing — CI-friendly.
	(( ${#warnings[@]} == 0 ))
}

# ---------------------------------------------------------------------------
# git_clone_as — clone into the correct identity root using the host alias.
# Usage: git_clone_as <id> <owner/repo> [target-dir]
# ---------------------------------------------------------------------------
git_clone_as() {
	local id="$1" repo="$2" target="${3:-}"
	if [[ -z "$id" || -z "$repo" ]]; then
		cat >&2 <<'EOF'
Usage: git_clone_as <id> <owner/repo> [target-dir]
Example: git_clone_as <identity> acme/my-personal-project
EOF
		return 1
	fi
	if [[ "$repo" != */* ]]; then
		echo "[git_clone_as] <owner/repo> must contain a slash (got: $repo)" >&2
		return 1
	fi

	# Look up the identity's directory from ~/.gitconfig includeIf.
	local dir
	dir="$(_git_identity_dir_for "$id")" || {
		echo "[git_clone_as] unknown identity '$id' — not found in ~/.gitconfig" >&2
		echo "Run: git_identity_list  to see configured identities." >&2
		return 1
	}

	local host_alias="github.com-$id"
	local url="git@${host_alias}:${repo}.git"
	(
		cd "$dir" || exit 1
		if [[ -n "$target" ]]; then
			git clone "$url" "$target"
		else
			git clone "$url"
		fi
	)
}

# Internal: resolve identity slug → directory from ~/.gitconfig includeIf.
_git_identity_dir_for() {
	local id="$1"
	local path
	path="$(git config --global --get-urlmatch nothing nothing 2>/dev/null || true)"  # no-op, ensure git is callable

	# Iterate all includeIf sections and match the tag line above each.
	# We rely on the FENCE_TAG comment (# dotfiles:identity:<id>) bootstrap.sh
	# writes immediately before the [includeIf] block.
	local gitconfig="$HOME/.gitconfig"
	[[ -r "$gitconfig" ]] || return 1

	awk -v id="$id" '
		$0 ~ "^# dotfiles:identity:" id "(\\b|[^a-z0-9_-])" { found = 1; next }
		found && /^\[includeIf "gitdir:/ {
			# Extract the path between "gitdir:" and "/"]
			match($0, /gitdir:[^"]+"/)
			if (RSTART) {
				s = substr($0, RSTART+7, RLENGTH-8)
				# Strip trailing slash.
				sub(/\/$/, "", s)
				print s
				exit 0
			}
		}
		/^# <<< dotfiles:identity:/ { found = 0 }
	' "$gitconfig"
}

# ---------------------------------------------------------------------------
# git_identity_list — table of configured identities.
# ---------------------------------------------------------------------------
git_identity_list() {
	local gitconfig="$HOME/.gitconfig"
	if [[ ! -r "$gitconfig" ]]; then
		echo "[git_identity_list] no ~/.gitconfig found" >&2
		return 1
	fi

	# Parse the fenced identity blocks.
	awk '
		BEGIN {
			printf "%-16s %-40s %-40s\n", "ID", "DIR", "INCLUDES"
			printf "%-16s %-40s %-40s\n", "--", "---", "--------"
		}
		/^# >>> dotfiles:identity:/ {
			# Expect:  # >>> dotfiles:identity:<id> >>>
			# The literal prefix "dotfiles:identity:" is 18 chars long.
			match($0, /dotfiles:identity:[^ ]+/)
			id = substr($0, RSTART+18, RLENGTH-18)
			dir = ""
			path = ""
			in_block = 1
			next
		}
		in_block && /^\[includeIf "gitdir:/ {
			match($0, /gitdir:[^"]+/)
			if (RSTART) dir = substr($0, RSTART+7, RLENGTH-7)
			sub(/\/$/, "", dir)
		}
		in_block && /^[[:space:]]*path[[:space:]]*=/ {
			sub(/^[^=]*=[[:space:]]*/, "")
			path = $0
		}
		in_block && /^# <<< dotfiles:identity:/ {
			printf "%-16s %-40s %-40s\n", id, dir, path
			in_block = 0
		}
	' "$gitconfig"
}

# ---------------------------------------------------------------------------
# git_identity_doctor — walk every repo under every managed root, verify
# user.email matches the identity's gitconfig and remote URL uses the
# correct host alias. CI-friendly: non-zero exit on drift.
# ---------------------------------------------------------------------------
git_identity_doctor() {
	local gitconfig="$HOME/.gitconfig"
	[[ -r "$gitconfig" ]] || { echo "[doctor] no ~/.gitconfig" >&2; return 1; }

	local drift=0

	# Parse fenced blocks into two arrays: IDS + DIRS.
	local ids=() dirs=() paths=()
	local line id dir path in_block=0
	while IFS= read -r line; do
		case "$line" in
			"# >>> dotfiles:identity:"*)
				id="${line#'# >>> dotfiles:identity:'}"
				id="${id% >>>}"
				in_block=1
				dir=""; path=""
				;;
			'[includeIf "gitdir:'*)
				if (( in_block )); then
					dir="${line#'[includeIf "gitdir:'}"
					dir="${dir%'"]'}"
					dir="${dir%/}"
				fi
				;;
			*'path'*'='*)
				if (( in_block )); then
					path="${line#*=}"
					# shellcheck disable=SC2001
					path="$(echo "$path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
				fi
				;;
			"# <<< dotfiles:identity:"*)
				if (( in_block )); then
					ids+=( "$id" )
					dirs+=( "$dir" )
					paths+=( "$path" )
					in_block=0
				fi
				;;
		esac
	done <"$gitconfig"

	if (( ${#ids[@]} == 0 )); then
		echo "[doctor] no managed identities found in $gitconfig"
		return 0
	fi

	local i
	for (( i=0; i<${#ids[@]}; i++ )); do
		local cid="${ids[$i]}"
		local cdir="${dirs[$i]/#\~/$HOME}"
		local cpath="${paths[$i]/#\~/$HOME}"

		# Expected email from the per-identity gitconfig.
		local expected_email=""
		if [[ -r "$cpath" ]]; then
			expected_email="$(git config --file "$cpath" user.email 2>/dev/null || true)"
		fi
		local host_alias="github.com-$cid"

		echo
		printf '== identity %s — dir=%s\n' "$cid" "$cdir"
		if [[ ! -d "$cdir" ]]; then
			printf '   (root does not exist yet)\n'
			continue
		fi

		# Find every .git dir under cdir (one level deep + nested).
		local repo
		while IFS= read -r -d '' repo; do
			local repo_dir
			repo_dir="$(dirname "$repo")"
			local actual_email actual_url
			actual_email="$(git -C "$repo_dir" config user.email 2>/dev/null || true)"
			actual_url="$(git -C "$repo_dir" config --get remote.origin.url 2>/dev/null || true)"
			local status='OK ' msg=''
			if [[ -n "$expected_email" && "$actual_email" != "$expected_email" ]]; then
				status='ERR'
				msg="email=$actual_email (expected $expected_email)"
				drift=1
			elif [[ -n "$actual_url" && "$actual_url" == git@github.com:* ]]; then
				status='WRN'
				msg="remote uses plain github.com — run 'git_identity_fix' inside $repo_dir"
			fi
			printf '   [%s] %s  %s\n' "$status" "$repo_dir" "$msg"
		done < <(find "$cdir" -type d -name .git -prune -print0 2>/dev/null)
	done

	return "$drift"
}

# ---------------------------------------------------------------------------
# git_identity_fix — rewrite the current repo's remote URL to use the
# identity-specific host alias, based on the directory it lives in.
# Opt-in (mutates .git/config). Idempotent.
# ---------------------------------------------------------------------------
git_identity_fix() {
	if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		echo "[fix] not inside a git repo" >&2
		return 1
	fi
	local root remote root_resolved
	root="$(git rev-parse --show-toplevel)"
	# Resolve symlinks (macOS /var → /private/var etc.) so the prefix match
	# below doesn't miss because one side is resolved and the other isn't.
	root_resolved="$(cd "$root" && pwd -P)"
	remote="$(git config --get remote.origin.url 2>/dev/null || true)"
	if [[ -z "$remote" ]]; then
		echo "[fix] no remote.origin.url in $root" >&2
		return 1
	fi

	# Resolve which identity directory this repo falls under.
	local gitconfig="$HOME/.gitconfig"
	local id="" in_block=0 cur_id=""
	while IFS= read -r line; do
		case "$line" in
			"# >>> dotfiles:identity:"*)
				cur_id="${line#'# >>> dotfiles:identity:'}"
				cur_id="${cur_id% >>>}"
				in_block=1
				;;
			'[includeIf "gitdir:'*)
				if (( in_block )); then
					local cdir="${line#'[includeIf "gitdir:'}"
					cdir="${cdir%'"]'}"
					cdir="${cdir%/}"
					cdir="${cdir/#\~/$HOME}"
					# Resolve the include-dir too for a fair comparison.
					local cdir_resolved="$cdir"
					[[ -d "$cdir" ]] && cdir_resolved="$(cd "$cdir" && pwd -P)"
					if [[ "$root" == "$cdir"/* || "$root" == "$cdir" \
					   || "$root_resolved" == "$cdir_resolved"/* \
					   || "$root_resolved" == "$cdir_resolved" ]]; then
						id="$cur_id"
					fi
				fi
				;;
			"# <<< dotfiles:identity:"*)
				in_block=0
				;;
		esac
	done <"$gitconfig"

	if [[ -z "$id" ]]; then
		echo "[fix] $root isn't inside any managed identity directory" >&2
		return 1
	fi

	case "$remote" in
		git@github.com:*)
			local new="git@github.com-${id}:${remote#git@github.com:}"
			echo "[fix] $remote → $new"
			git remote set-url origin "$new"
			;;
		git@github.com-*:*)
			echo "[fix] remote already uses a host alias: $remote"
			;;
		*)
			echo "[fix] remote '$remote' isn't a github.com SSH URL; skipping" >&2
			return 1
			;;
	esac
}

# ---------------------------------------------------------------------------
# git_identity_bootstrap — convenience wrapper so users don't need to
# remember the path to bootstrap.sh.
# ---------------------------------------------------------------------------
git_identity_bootstrap() {
	if [[ -z "${IDENTITIES_DIR:-}" || ! -x "$IDENTITIES_DIR/bootstrap.sh" ]]; then
		echo "[bootstrap] cannot locate $IDENTITIES_DIR/bootstrap.sh" >&2
		return 1
	fi
	"$IDENTITIES_DIR/bootstrap.sh" "$@"
}
