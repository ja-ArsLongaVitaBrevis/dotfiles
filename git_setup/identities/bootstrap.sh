#!/usr/bin/env bash
# bootstrap.sh — provision one git identity: ssh config, gitconfig includes,
# per-identity gitconfig file, allowed_signers entry.
#
# See git_setup/identities/README.md for the end-to-end flow.
#
# Usage:
#   bootstrap.sh \
#       --id    <identity> \
#       --dir   ~/Code<identity> \
#       --name  "User Name" \
#       --email "user@example.com" \
#       --auth-pub "ssh-ed25519 AAAA… user-auth" \
#       --sign-pub "ssh-ed25519 AAAA… user-sign" \
#       [--host-alias github.com-<identity>] \
#       [--dry-run] \
#       [--remove]
#
# Idempotent: re-running with the same args is a no-op. Re-running with a
# rotated key updates only the files that reference it.

set -euo pipefail

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LIB_DIR="$SCRIPT_DIR/lib"
TMPL_DIR="$SCRIPT_DIR/templates"

# shellcheck source=lib/_pubkey.sh
source "$LIB_DIR/_pubkey.sh"
# shellcheck source=lib/_fenced_block.sh
source "$LIB_DIR/_fenced_block.sh"
# shellcheck source=lib/_allowed_signers.sh
source "$LIB_DIR/_allowed_signers.sh"

GITCONFIG_GLOBAL="$HOME/.gitconfig"
SSH_CONFIG="$HOME/.ssh/config"
ALLOWED_SIGNERS="$HOME/.ssh/allowed_signers"
SSH_DIR="$HOME/.ssh"

GLOBAL_SENTINEL="# dotfiles:identities:global"
BACKUP_KEEP=3

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
_color() { [[ -t 1 ]] && printf '\033[%sm' "$1" || true; }
_reset() { [[ -t 1 ]] && printf '\033[0m'      || true; }

log_info()  { printf '%s[bootstrap]%s %s\n' "$(_color 36)"    "$(_reset)" "$*"; }
log_ok()    { printf '%s[bootstrap]%s %s\n' "$(_color '1;32')" "$(_reset)" "$*"; }
log_warn()  { printf '%s[bootstrap]%s %s\n' "$(_color '1;33')" "$(_reset)" "$*" >&2; }
log_err()   { printf '%s[bootstrap]%s %s\n' "$(_color '1;31')" "$(_reset)" "$*" >&2; }
log_step()  { printf '\n%s==> %s%s\n' "$(_color '1;34')" "$*" "$(_reset)"; }

die() { log_err "$*"; exit 1; }

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
ID=""
DIR=""
NAME=""
EMAIL=""
AUTH_PUB=""
SIGN_PUB=""
HOST_ALIAS=""
DRY_RUN=0
REMOVE=0

usage() {
	cat <<'EOF'
bootstrap.sh — provision one git identity (SSH + gitconfig + signing).

Required:
  --id    <slug>       Identity short name, [a-z0-9_-]+
  --dir   <path>       Identity root directory (absolute; ~ is expanded)
  --name  <str>        Full name for git commits
  --email <addr>       Email for git commits and allowed_signers

Required unless --remove:
  --auth-pub <blob>    ssh-ed25519 public key for authentication
  --sign-pub <blob>    ssh-ed25519 public key for commit signing

Optional:
  --host-alias <name>  SSH Host alias (default: github.com-<id>)
  --dry-run            Print every mutation; change nothing on disk
  --remove             Tear down: remove fenced blocks, delete .pub files
                       and ~/.gitconfig-<id>, remove allowed_signers line
  -h, --help           This message

Examples:
  bootstrap.sh \
    --id user --dir ~/CodeUser \
    --name "User Name" --email "user@example.com" \
    --auth-pub "ssh-ed25519 AAAA… user-auth" \
    --sign-pub "ssh-ed25519 AAAA… user-sign"

  bootstrap.sh --id user --dir ~/CodeUser --name x --email x --remove
EOF
}

while (($#)); do
	case "$1" in
		--id)         ID="$2";         shift 2 ;;
		--dir)        DIR="$2";        shift 2 ;;
		--name)       NAME="$2";       shift 2 ;;
		--email)      EMAIL="$2";      shift 2 ;;
		--auth-pub)   AUTH_PUB="$2";   shift 2 ;;
		--sign-pub)   SIGN_PUB="$2";   shift 2 ;;
		--host-alias) HOST_ALIAS="$2"; shift 2 ;;
		--dry-run)    DRY_RUN=1;       shift ;;
		--remove)     REMOVE=1;        shift ;;
		-h|--help)    usage; exit 0 ;;
		*)            die "unknown argument: $1 (see --help)" ;;
	esac
done

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
[[ -n "$ID"    ]] || die "--id is required"
[[ -n "$DIR"   ]] || die "--dir is required"
[[ -n "$NAME"  ]] || die "--name is required"
[[ -n "$EMAIL" ]] || die "--email is required"

if ! [[ "$ID" =~ ^[a-z0-9_-]+$ ]]; then
	die "--id '$ID' must match [a-z0-9_-]+ (lowercase, no spaces)"
fi
if ! [[ "$EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; then
	die "--email '$EMAIL' doesn't look like an email address"
fi

# Expand leading ~ in --dir (no word-split, keep the rest literal).
if [[ "$DIR" == "~" ]]; then
	DIR="$HOME"
elif [[ "$DIR" == "~/"* ]]; then
	DIR="$HOME/${DIR#~/}"
fi
[[ "$DIR" == /* ]] || die "--dir '$DIR' must be absolute"

HOST_ALIAS="${HOST_ALIAS:-github.com-$ID}"

if (( ! REMOVE )); then
	[[ -n "$AUTH_PUB" ]] || die "--auth-pub is required (unless --remove)"
	[[ -n "$SIGN_PUB" ]] || die "--sign-pub is required (unless --remove)"
	pubkey_validate "$AUTH_PUB" || die "invalid --auth-pub"
	pubkey_validate "$SIGN_PUB" || die "invalid --sign-pub"
fi

# Derived paths.
AUTH_PUB_PATH="$SSH_DIR/id_ed25519_${ID}_auth.pub"
SIGN_PUB_PATH="$SSH_DIR/id_ed25519_${ID}_sign.pub"
IDENTITY_GITCONFIG="$HOME/.gitconfig-$ID"
FENCE_TAG="dotfiles:identity:$ID"

# ---------------------------------------------------------------------------
# Dry-run wrapper
# ---------------------------------------------------------------------------
# All destructive helpers below go through `mutate <label> <cmd...>`.
# In dry-run mode we only log what we would do.
mutate() {
	local label="$1"; shift
	if (( DRY_RUN )); then
		printf '  [dry-run] %s\n' "$label"
		return 0
	fi
	"$@"
}

# ---------------------------------------------------------------------------
# Backups
# ---------------------------------------------------------------------------
backup_file() {
	local f="$1"
	[[ -e "$f" ]] || return 0
	local ts
	ts="$(date +%Y%m%d-%H%M%S)"
	local bak="${f}.bak.${ts}"
	if (( DRY_RUN )); then
		printf '  [dry-run] backup %s → %s\n' "$f" "$bak"
		return 0
	fi
	cp -p "$f" "$bak"
	# Trim old backups, keep most recent $BACKUP_KEEP.
	local old
	# shellcheck disable=SC2207
	old=( $(ls -1t "${f}".bak.* 2>/dev/null || true) )
	if (( ${#old[@]} > BACKUP_KEEP )); then
		local i
		for (( i=BACKUP_KEEP; i<${#old[@]}; i++ )); do
			rm -f "${old[$i]}"
		done
	fi
}

# ---------------------------------------------------------------------------
# Template rendering (Bash parameter expansion, no sed)
# ---------------------------------------------------------------------------
render_template() {
	# Usage: render_template <template-path>
	# Placeholders supported: {{ID}} {{NAME}} {{EMAIL}} {{HOST_ALIAS}}
	#   {{AUTH_PUB_PATH}} {{SIGN_PUB_PATH}}
	local path="$1"
	local content
	content="$(cat "$path")"
	content="${content//\{\{ID\}\}/$ID}"
	content="${content//\{\{NAME\}\}/$NAME}"
	content="${content//\{\{EMAIL\}\}/$EMAIL}"
	content="${content//\{\{HOST_ALIAS\}\}/$HOST_ALIAS}"
	content="${content//\{\{AUTH_PUB_PATH\}\}/$AUTH_PUB_PATH}"
	content="${content//\{\{SIGN_PUB_PATH\}\}/$SIGN_PUB_PATH}"
	printf '%s' "$content"
}

# ---------------------------------------------------------------------------
# Step implementations
# ---------------------------------------------------------------------------

ensure_ssh_dir() {
	if [[ ! -d "$SSH_DIR" ]]; then
		log_info "creating $SSH_DIR (mode 700)"
		mutate "mkdir -p $SSH_DIR && chmod 700" \
			bash -c "mkdir -p '$SSH_DIR' && chmod 700 '$SSH_DIR'"
	fi
}

ensure_identity_root() {
	if [[ -d "$DIR" ]]; then
		log_info "identity root exists: $DIR"
	else
		log_info "creating identity root: $DIR"
		mutate "mkdir -p $DIR" mkdir -p "$DIR"
	fi
}

seed_global_gitconfig() {
	# First-run only: write the global defaults. If the sentinel isn't
	# present we (re)seed, preserving user edits above/below the template
	# is NOT a goal — if you edit ~/.gitconfig by hand, keep the sentinel.
	if [[ -e "$GITCONFIG_GLOBAL" ]] && grep -qF "$GLOBAL_SENTINEL" "$GITCONFIG_GLOBAL"; then
		log_info "global ~/.gitconfig already seeded (sentinel found)"
		return 0
	fi
	log_info "seeding global defaults into $GITCONFIG_GLOBAL"
	backup_file "$GITCONFIG_GLOBAL"
	local body
	body="$(cat "$TMPL_DIR/gitconfig-global.tmpl")"
	if [[ -e "$GITCONFIG_GLOBAL" ]]; then
		# Prepend our defaults to the existing file, so the user keeps their
		# aliases / custom sections intact below.
		local existing
		existing="$(cat "$GITCONFIG_GLOBAL")"
		local combined="${body}"$'\n\n'"${existing}"
		mutate "seed $GITCONFIG_GLOBAL" bash -c "printf '%s' \"\$1\" >'$GITCONFIG_GLOBAL' && chmod 600 '$GITCONFIG_GLOBAL'" _ "$combined"
	else
		mutate "seed $GITCONFIG_GLOBAL" bash -c "printf '%s\n' \"\$1\" >'$GITCONFIG_GLOBAL' && chmod 600 '$GITCONFIG_GLOBAL'" _ "$body"
	fi
}

write_pubkeys() {
	log_info "writing $AUTH_PUB_PATH"
	if (( DRY_RUN )); then
		printf '  [dry-run] write %s (auth pub, %d chars)\n' "$AUTH_PUB_PATH" "${#AUTH_PUB}"
	else
		pubkey_write "$AUTH_PUB" "$AUTH_PUB_PATH" || die "failed to write auth pub"
	fi
	log_info "writing $SIGN_PUB_PATH"
	if (( DRY_RUN )); then
		printf '  [dry-run] write %s (sign pub, %d chars)\n' "$SIGN_PUB_PATH" "${#SIGN_PUB}"
	else
		pubkey_write "$SIGN_PUB" "$SIGN_PUB_PATH" || die "failed to write sign pub"
	fi
}

render_identity_gitconfig() {
	log_info "rendering $IDENTITY_GITCONFIG"
	local content
	content="$(render_template "$TMPL_DIR/gitconfig-identity.tmpl")"
	backup_file "$IDENTITY_GITCONFIG"
	if (( DRY_RUN )); then
		printf '  [dry-run] write %s (%d bytes):\n' "$IDENTITY_GITCONFIG" "${#content}"
		printf '%s\n' "$content" | sed 's/^/      /'
	else
		local tmp
		tmp="$(mktemp "${IDENTITY_GITCONFIG}.XXXXXX")"
		printf '%s\n' "$content" >"$tmp"
		chmod 600 "$tmp"
		mv -f "$tmp" "$IDENTITY_GITCONFIG"
	fi
}

upsert_gitconfig_include() {
	log_info "upserting [includeIf \"gitdir:$DIR/\"] block in $GITCONFIG_GLOBAL"
	backup_file "$GITCONFIG_GLOBAL"
	# Trailing slash on gitdir is important — it makes the match prefix-based.
	local block
	block="$(cat <<EOF
# ${FENCE_TAG} — gitdir-scoped include for identity '${ID}'
[includeIf "gitdir:${DIR}/"]
	path = ${IDENTITY_GITCONFIG}
EOF
)"
	if (( DRY_RUN )); then
		printf '  [dry-run] fenced_upsert %s tag=%s\n' "$GITCONFIG_GLOBAL" "$FENCE_TAG"
		printf '%s\n' "$block" | sed 's/^/      /'
	else
		fenced_upsert "$GITCONFIG_GLOBAL" "$FENCE_TAG" "$block" 600
	fi
}

upsert_ssh_host_block() {
	log_info "upserting Host $HOST_ALIAS block in $SSH_CONFIG"
	backup_file "$SSH_CONFIG"
	local block
	block="$(render_template "$TMPL_DIR/ssh-config-identity.tmpl")"
	if (( DRY_RUN )); then
		printf '  [dry-run] fenced_upsert %s tag=%s\n' "$SSH_CONFIG" "$FENCE_TAG"
		printf '%s\n' "$block" | sed 's/^/      /'
	else
		fenced_upsert "$SSH_CONFIG" "$FENCE_TAG" "$block" 600
	fi
}

upsert_allowed_signer() {
	log_info "upserting allowed_signers entry for $EMAIL"
	backup_file "$ALLOWED_SIGNERS"
	if (( DRY_RUN )); then
		printf '  [dry-run] allowed_signers_upsert %s email=%s\n' "$ALLOWED_SIGNERS" "$EMAIL"
	else
		allowed_signers_upsert "$ALLOWED_SIGNERS" "$EMAIL" "$SIGN_PUB" \
			|| die "failed to update $ALLOWED_SIGNERS"
	fi
}

print_summary() {
	local auth_fp="(dry-run)" sign_fp="(dry-run)"
	if (( ! DRY_RUN )); then
		auth_fp="$(pubkey_fingerprint "$AUTH_PUB_PATH" 2>/dev/null || echo '?')"
		sign_fp="$(pubkey_fingerprint "$SIGN_PUB_PATH" 2>/dev/null || echo '?')"
	fi

	cat <<EOF

$(_color '1;32')━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(_reset)
$(_color '1;32')Identity '${ID}' provisioned.$(_reset)
$(_color '1;32')━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(_reset)

  Name              ${NAME}
  Email             ${EMAIL}
  Root dir          ${DIR}
  SSH host alias    ${HOST_ALIAS}
  Auth pub          ${AUTH_PUB_PATH}
                    ${auth_fp}
  Sign pub          ${SIGN_PUB_PATH}
                    ${sign_fp}
  Per-id config     ${IDENTITY_GITCONFIG}
  allowed_signers   ${ALLOWED_SIGNERS}

$(_color '1;34')Next steps:$(_reset)
  1. In 1Password, verify the fingerprints above match the items you created.
  2. On GitHub (Settings → SSH and GPG keys) make sure:
       - Auth pub is registered as "Authentication Key"
       - Sign pub is registered as "Signing Key"
  3. Verify the SSH alias works:
       ssh -T git@${HOST_ALIAS}
  4. Clone into ${DIR} using the alias:
       cd ${DIR} && git clone git@${HOST_ALIAS}:<owner>/<repo>.git
     …or use the helper:
       git_clone_as ${ID} <owner>/<repo>
  5. Inside any repo under ${DIR}, run:
       git_whoami
     to confirm the identity resolves correctly.
EOF
}

# ---------------------------------------------------------------------------
# Remove flow
# ---------------------------------------------------------------------------
do_remove() {
	log_step "Removing identity '$ID'"

	log_info "removing fenced block from $GITCONFIG_GLOBAL"
	backup_file "$GITCONFIG_GLOBAL"
	mutate "fenced_remove $GITCONFIG_GLOBAL tag=$FENCE_TAG" \
		fenced_remove "$GITCONFIG_GLOBAL" "$FENCE_TAG"

	log_info "removing fenced block from $SSH_CONFIG"
	backup_file "$SSH_CONFIG"
	mutate "fenced_remove $SSH_CONFIG tag=$FENCE_TAG" \
		fenced_remove "$SSH_CONFIG" "$FENCE_TAG"

	log_info "removing allowed_signers entry for $EMAIL"
	backup_file "$ALLOWED_SIGNERS"
	mutate "allowed_signers_remove $ALLOWED_SIGNERS email=$EMAIL" \
		allowed_signers_remove "$ALLOWED_SIGNERS" "$EMAIL"

	if [[ -e "$IDENTITY_GITCONFIG" ]]; then
		log_info "deleting $IDENTITY_GITCONFIG"
		mutate "rm $IDENTITY_GITCONFIG" rm -f "$IDENTITY_GITCONFIG"
	fi
	for f in "$AUTH_PUB_PATH" "$SIGN_PUB_PATH"; do
		if [[ -e "$f" ]]; then
			log_info "deleting $f"
			mutate "rm $f" rm -f "$f"
		fi
	done

	log_ok "identity '$ID' removed. Directory $DIR and its repos were NOT touched."
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if (( DRY_RUN )); then
	log_warn "DRY-RUN mode — no files will be written."
fi

if (( REMOVE )); then
	do_remove
	exit 0
fi

log_step "Provisioning identity '$ID'"
ensure_ssh_dir
ensure_identity_root
seed_global_gitconfig
write_pubkeys
render_identity_gitconfig
upsert_gitconfig_include
upsert_ssh_host_block
upsert_allowed_signer
print_summary

if (( DRY_RUN )); then
	log_warn "DRY-RUN complete — nothing was written."
fi
