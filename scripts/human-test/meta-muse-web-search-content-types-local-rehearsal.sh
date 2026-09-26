#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
EVIDENCE_BASE="docs/evidence/meta-muse-web-search-content-types-local"
TEST_FILE="tests/providers/muse-spark-web-search-compat.test.ts"
BUN_BIN="${BUN_BIN:-bun}"
RUN_STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
EVIDENCE_REL="$EVIDENCE_BASE/$RUN_STAMP"
EVIDENCE_DIR="$REPO_ROOT/$EVIDENCE_REL"
STDOUT_LOG="$EVIDENCE_DIR/stdout.log"
STDERR_LOG="$EVIDENCE_DIR/stderr.log"

mkdir -p "$EVIDENCE_DIR"
cd "$REPO_ROOT"
: > "$STDOUT_LOG"
: > "$STDERR_LOG"

sanitize_output() {
  if [ -n "${HOME:-}" ]; then
    sed -e "s|$REPO_ROOT/||g" -e "s|$HOME|~|g"
  else
    sed -e "s|$REPO_ROOT/||g"
  fi
}

status_without_evidence() {
  git status --porcelain=v1 --untracked-files=all | grep -Fv "?? $EVIDENCE_REL/" || true
}

printf 'bun --version\n' > "$EVIDENCE_DIR/commands.log"
printf 'bun test %s\n' "$TEST_FILE" >> "$EVIDENCE_DIR/commands.log"
printf 'bun ' >> "$STDOUT_LOG"
printf 'Focused test stdout and stderr are combined and path-sanitized in stdout.log.\n' > "$STDERR_LOG"

status_before="$(status_without_evidence)"
test_exit=127
if command -v "$BUN_BIN" >/dev/null 2>&1; then
  "$BUN_BIN" --version >> "$STDOUT_LOG" 2>> "$STDERR_LOG"
  set +e
  "$BUN_BIN" test "$TEST_FILE" 2>&1 | sanitize_output >> "$STDOUT_LOG"
  command_status=("${PIPESTATUS[@]}")
  test_exit="${command_status[0]}"
  set -e
else
  printf 'Bun command is unavailable.\n' >> "$STDERR_LOG"
fi

status_after="$(status_without_evidence)"
status="pass"
warnings='[]'
workspace_exit=0
if [ "$status_before" != "$status_after" ]; then
  status="fail"
  workspace_exit=1
fi
if [ "$test_exit" -ne 0 ]; then
  status="fail"
fi
if [ "$workspace_exit" -ne 0 ] && [ "$test_exit" -ne 0 ]; then
  warnings='["worktree_changed_outside_evidence","focused_test_failed_or_bun_unavailable"]'
elif [ "$workspace_exit" -ne 0 ]; then
  warnings='["worktree_changed_outside_evidence"]'
elif [ "$test_exit" -ne 0 ]; then
  warnings='["focused_test_failed_or_bun_unavailable"]'
fi

cat > "$EVIDENCE_DIR/summary.json" <<EOF
{
  "status": "$status",
  "evidence_dir": "$EVIDENCE_REL",
  "steps": [
    {"name": "bun_test_$TEST_FILE", "exit_code": $test_exit},
    {"name": "worktree_state_comparison", "exit_code": $workspace_exit}
  ],
  "warnings": $warnings
}
EOF

printf 'status=%s evidence_dir=%s exit_code=%s\n' "$status" "$EVIDENCE_REL" "$((test_exit > workspace_exit ? test_exit : workspace_exit))"
if [ "$test_exit" -ne 0 ] || [ "$workspace_exit" -ne 0 ]; then
  exit 1
fi
