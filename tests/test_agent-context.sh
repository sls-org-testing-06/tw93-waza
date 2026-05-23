#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

CHECKER="$ROOT/skills/health/scripts/check-agent-context.sh"

tmpdir=$(make_tmpdir)
project="$tmpdir/project"
home_dir="$tmpdir/home"
mkdir -p "$project" "$home_dir/.codex"

printf '%s\n' \
  '## Project' \
  'Repository Map: source lives in src.' \
  '## Verification' \
  'Run `make test`.' \
  '## Boundaries' \
  'Do not rewrite unrelated modules.' \
  > "$project/AGENTS.md"
printf '%s\n' 'global codex rule' > "$home_dir/.codex/AGENTS.md"

# config.toml with sensitive keys that must be redacted before output.
{
  printf '%s\n' 'api_key = "SHOULD_NOT_LEAK"'
  printf '%s\n' 'token = "TOKEN_SHOULD_NOT_LEAK"'
  printf '%s\n' '[features]'
  printf '%s\n' 'hooks = true'
  printf '%s\n' '[plugins."github@openai-curated"]'
  printf '%s\n' 'enabled = true'
  printf '%s\n' "[projects.\"$project\"]"
  printf '%s\n' 'trust_level = "trusted"'
} > "$home_dir/.codex/config.toml"

HOME="$home_dir" bash "$CHECKER" "$project" summary >"$tmpdir/context.out"
grep -q '^agent_instruction_status: PASS$' "$tmpdir/context.out"
grep -q '^codex_status: PASS$' "$tmpdir/context.out"
grep -q '^project_trust: exact:trusted$' "$tmpdir/context.out"
grep -q 'api_key=\[REDACTED\]' "$tmpdir/context.out"
grep -q 'token=\[REDACTED\]' "$tmpdir/context.out"
if grep -q 'SHOULD_NOT_LEAK' "$tmpdir/context.out"; then
  echo "agent context leaked sensitive config"; exit 1
fi

# Delegation: CLAUDE.md pointing to AGENTS.md should show delegates_to=yes and
# clear the conflict warning.
printf '%s\n' '@AGENTS.md' > "$project/CLAUDE.md"
HOME="$home_dir" bash "$CHECKER" "$project" summary >"$tmpdir/delegation.out"
grep -q '^claude_delegates_to_agents: yes$' "$tmpdir/delegation.out"
grep -q '^conflict_status: PASS$' "$tmpdir/delegation.out"

echo "agent context smoke: ok"
