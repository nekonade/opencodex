#!/usr/bin/env bash
# Run the Meta Muse offline Human Test and save local evidence; supported on macOS and Linux.
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

if ! mkdir -p "$EVIDENCE_DIR"; then
  printf 'status=fail reason=evidence_directory_unavailable evidence_dir=%s exit_code=1\n' "$EVIDENCE_REL"
  exit 1
fi
if ! cd "$REPO_ROOT"; then
  printf 'status=fail reason=repository_unavailable evidence_dir=%s exit_code=1\n' "$EVIDENCE_REL"
  exit 1
fi
if ! : > "$STDOUT_LOG" || ! : > "$STDERR_LOG"; then
  printf 'status=fail reason=evidence_logs_unavailable evidence_dir=%s exit_code=1\n' "$EVIDENCE_REL"
  exit 1
fi

sanitize_output() {
  if [ -n "${HOME:-}" ]; then
    sed -e "s|$REPO_ROOT/||g" -e "s|$HOME|~|g"
  else
    sed -e "s|$REPO_ROOT/||g"
  fi
}

json_escape() {
  local json_value="$1"
  json_value="${json_value//\\/\\\\}"
  json_value="${json_value//\"/\\\"}"
  json_value="${json_value//$'\n'/\\n}"
  json_value="${json_value//$'\r'/\\r}"
  json_value="${json_value//$'\t'/\\t}"
  printf '%s' "$json_value"
}

git_status_snapshot() {
  git status --porcelain=v1 --untracked-files=all
}

warnings=()
workspace_exit=0
capture_exit=0
git_status_exit=0
identity_exit=0
status_before="$(git_status_snapshot 2>> "$STDERR_LOG")"
status_before_exit=$?

worktree_path="$(git rev-parse --show-toplevel 2>> "$STDERR_LOG")"
worktree_path_exit=$?
branch_name="$(git branch --show-current 2>> "$STDERR_LOG")"
branch_exit=$?
head_sha="$(git rev-parse HEAD 2>> "$STDERR_LOG")"
head_exit=$?
branch_display="$branch_name"
if [ -z "$branch_display" ] && [ "$branch_exit" -eq 0 ]; then
  branch_display="detached"
fi
if [ "$worktree_path_exit" -ne 0 ] || [ "$branch_exit" -ne 0 ] || [ "$head_exit" -ne 0 ] \
  || [ -z "$worktree_path" ] || [ -z "$head_sha" ]; then
  warnings+=("worktree_metadata_unavailable")
  workspace_exit=1
  identity_exit=1
fi

printf '%s --version\n' "$BUN_BIN" > "$EVIDENCE_DIR/commands.log"
printf '%s test %s\n' "$BUN_BIN" "$TEST_FILE" >> "$EVIDENCE_DIR/commands.log"
printf 'Focused test stdout and stderr are combined and path-sanitized in stdout.log.\n' >> "$STDERR_LOG"

bun_available_exit=0
bun_version_exit="null"
test_exit="null"
if command -v "$BUN_BIN" >/dev/null 2>&1; then
  "$BUN_BIN" --version >> "$STDOUT_LOG" 2>> "$STDERR_LOG"
  bun_version_exit=$?
  if [ "$bun_version_exit" -eq 0 ]; then
    "$BUN_BIN" test "$TEST_FILE" 2>&1 | sanitize_output >> "$STDOUT_LOG"
    command_status=("${PIPESTATUS[@]}")
    test_exit="${command_status[0]}"
    capture_exit="${command_status[1]}"
  else
    warnings+=("bun_version_failed")
  fi
else
  bun_available_exit=127
  warnings+=("bun_unavailable")
  printf 'Bun command is unavailable; the focused test was not run.\n' >> "$STDERR_LOG"
fi

if [ "$capture_exit" -ne 0 ]; then
  warnings+=("test_output_capture_failed")
  workspace_exit=1
fi
if [ "$status_before_exit" -ne 0 ]; then
  warnings+=("worktree_state_unavailable")
  workspace_exit=1
  git_status_exit=1
fi
status_after="$(git_status_snapshot 2>> "$STDERR_LOG")"
status_after_exit=$?
if [ "$status_after_exit" -ne 0 ]; then
  warnings+=("worktree_state_unavailable")
  workspace_exit=1
  git_status_exit=1
elif [ "$status_before" != "$status_after" ]; then
  warnings+=("worktree_changed")
  workspace_exit=1
  git_status_exit=1
fi

process_exit=0
if [ "$bun_available_exit" -ne 0 ]; then
  process_exit=127
elif [ "$bun_version_exit" != "null" ] && [ "$bun_version_exit" -ne 0 ]; then
  process_exit="$bun_version_exit"
elif [ "$test_exit" != "null" ] && [ "$test_exit" -ne 0 ]; then
  process_exit="$test_exit"
fi
if [ "$workspace_exit" -ne 0 ] && [ "$process_exit" -eq 0 ]; then
  process_exit=1
fi
if [ "$process_exit" -ne 0 ]; then
  if [ "$test_exit" != "null" ] && [ "$test_exit" -ne 0 ]; then
    warnings+=("focused_test_failed")
  fi
fi

status="pass"
if [ "$process_exit" -ne 0 ]; then
  status="fail"
fi
warnings_json="["
warning_text=""
if [ "${#warnings[@]}" -gt 0 ]; then
  for warning in "${warnings[@]}"; do
    if [ -n "$warning_text" ]; then
      warnings_json+=", "
      warning_text="${warning_text},"
    fi
    warnings_json+="\"$warning\""
    warning_text="${warning_text}${warning}"
  done
fi
warnings_json+="]"

worktree_path_json="$(json_escape "$worktree_path")"
branch_name_json="$(json_escape "$branch_display")"
head_sha_json="$(json_escape "$head_sha")"
cat > "$EVIDENCE_DIR/summary.json" <<EOF
{
  "status": "$status",
  "process_exit_code": $process_exit,
  "worktree": {
    "path": "$worktree_path_json",
    "branch": "$branch_name_json",
    "head": "$head_sha_json"
  },
  "evidence_dir": "$EVIDENCE_REL",
  "steps": [
    {"name": "bun_availability", "exit_code": $bun_available_exit},
    {"name": "bun_version", "exit_code": $bun_version_exit},
    {"name": "focused_test_$TEST_FILE", "exit_code": $test_exit},
    {"name": "test_output_capture", "exit_code": $capture_exit},
    {"name": "worktree_identity", "exit_code": $identity_exit},
    {"name": "git_status_comparison", "exit_code": $git_status_exit}
  ],
  "warnings": $warnings_json
}
EOF
summary_write_exit=$?
if [ "$summary_write_exit" -ne 0 ]; then
  process_exit=1
  status="fail"
  warnings+=("summary_write_failed")
  warning_text+="${warning_text:+,}summary_write_failed"
fi

printf 'status=%s worktree_path=%s branch=%s head=%s evidence_dir=%s bun_exit_code=%s test_exit_code=%s workspace_exit_code=%s exit_code=%s warnings=%s\n' \
  "$status" "$worktree_path" "$branch_display" "$head_sha" "$EVIDENCE_REL" \
  "$bun_available_exit" "$test_exit" "$workspace_exit" "$process_exit" "${warning_text:-none}"
exit "$process_exit"
