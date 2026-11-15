#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
agent="$root/crates/buzz-agent/Cargo.toml"
lock="$root/Cargo.lock"
deny="$root/deny.toml"
source="$root/crates/buzz-agent/src/mcp.rs"

fail() { echo "rmcp boundary: $*" >&2; exit 1; }
check_agent_manifest() {
  local manifest=$1
  local rmcp_line
  rmcp_line=$(grep '^rmcp = ' "$manifest" || true)
  [[ -n "$rmcp_line" ]] || return 1
  grep -Fq 'rmcp = { version = "1"' <<<"$rmcp_line" || return 1
  grep -Fq 'default-features = false' <<<"$rmcp_line" || return 1
  grep -Fq 'transport-child-process' <<<"$rmcp_line" || return 1
  ! grep -Fq 'transport-streamable-http' <<<"$rmcp_line"
}
check_agent_manifest "$agent" || fail 'buzz-agent rmcp dependency must pin v1, disable defaults, and use child-process transport only'

# Mutation guard: removing rmcp's default-features assertion must fail this check.
mutated=$(mktemp)
trap 'rm -f "$mutated"' EXIT
sed '/^rmcp = / s/, default-features = false//' "$agent" >"$mutated"
if check_agent_manifest "$mutated"; then
  fail 'rmcp default-features mutation was not rejected'
fi
grep -Fq 'TokioChildProcess' "$source" || fail 'buzz-agent must construct TokioChildProcess'
grep -Fq 'name = "rmcp"' "$lock" || fail 'Cargo.lock must contain rmcp'
grep -Fq 'version = "3.9.0"' "$lock" || fail 'patched rmcp 3.9.0 must remain locked'
grep -Fq 'version = "<3.9.0"' "$deny" || fail 'deny.toml must fence older rmcp'
grep -Fq 'wrappers = ["buzz-agent"]' "$deny" || fail 'older rmcp fence must be limited to buzz-agent'
grep -Fq 'transport-child-process' "$deny" || fail 'deny.toml must document the subprocess-only exception'

# The host-runtime path moved to the mesh smoke workspace; do not pin the old
# buzz-relay path in a boundary test that would fail on a valid main tree.
grep -Fq 'mesh-llm-host-runtime' "$root/crates/buzz-mesh-smoke/Cargo.toml" || fail 'mesh smoke must declare host runtime'
echo 'rmcp boundary: main-tree transport and dependency fences pass'
