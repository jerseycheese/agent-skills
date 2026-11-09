#!/usr/bin/env bash
# Tests the merge gate in skills/backlog-routing/scripts/pr-ready.sh against a fake `gh`.
# The fake serves canned JSON for each API call and applies the --jq filter with real jq,
# so pr-ready.sh's own filters run against it. Needs bash and jq.

set -u

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SCRIPT="$ROOT/skills/backlog-routing/scripts/pr-ready.sh"
HEAD=1111111111111111111111111111111111111111
OLD=2222222222222222222222222222222222222222

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"

cat >"$tmp/bin/gh" <<'EOF'
#!/usr/bin/env bash
# Fake gh: `gh api <endpoint> ... --jq <filter>` -> jq -r <filter> on a fixture file.
endpoint="" filter="."
shift # api
while [ $# -gt 0 ]; do
  case "$1" in
    --jq) filter="$2"; shift 2 ;;
    -f | -F) shift 2 ;;
    *) [ -z "$endpoint" ] && endpoint="$1"; shift ;;
  esac
done
case "$endpoint" in
  'repos/{owner}/{repo}') file=repo.json ;;
  graphql) file=pr.json ;;
  */check-runs*) file=checks.json ;;
  */status) file=status.json ;;
  *) echo "fake gh: unexpected endpoint $endpoint" >&2; exit 1 ;;
esac
jq -r "$filter" "$FAKE_GH_DIR/$file"
EOF
chmod +x "$tmp/bin/gh"

echo '{"full_name": "o/r"}' >"$tmp/repo.json"
echo '{"total_count": 1, "check_runs": [{"id": 1, "name": "lint", "status": "completed", "conclusion": "success"}]}' >"$tmp/checks.json"
echo '{"statuses": []}' >"$tmp/status.json"

PASS_RUN='{"id": 1, "check_suite": {"id": 1}, "name": "lint", "status": "completed", "conclusion": "success"}'
CODEX_OK="| **Review** | **Completed** \`${HEAD:0:7}\` |"

# Per-case fixture knobs. check() resets them after each case.
reset_knobs() {
  DRAFT=false
  COMMENTS='[]' # extra comment nodes
  MORE_COMMENTS=false # older comments cut off by the 100-comment window
  THREADS='[]'  # review thread nodes
  RUNS="[$PASS_RUN]"
  BOT_ARGS="--bot codex" # the review bot the caller opts into; empty for none
}
reset_knobs

# write_pr <codex summary row>: an open PR on $HEAD with a Codex summary (none if the row is
# empty), plus the knobs above.
write_pr() {
  local codex='[]'
  if [ -n "$1" ]; then
    codex=$(jq -n --arg body "$(printf '<!-- codex-pull-request-review-summary -->\n| Task | Status |\n%s' "$1")" \
      '[{body: $body, author: {__typename: "Bot", login: "chatgpt-codex-connector"}}]')
  fi
  jq -n --arg head "$HEAD" --argjson draft "$DRAFT" --argjson codex "$codex" \
    --argjson extra "$COMMENTS" --argjson more "$MORE_COMMENTS" --argjson threads "$THREADS" '{data: {viewer: {login: "me"}, repository: {pullRequest: {
    state: "OPEN", isDraft: $draft, mergeable: "MERGEABLE", mergeStateStatus: "CLEAN", headRefOid: $head,
    comments: {pageInfo: {hasPreviousPage: $more}, nodes: ($codex + $extra)},
    reviewThreads: {pageInfo: {hasNextPage: false}, nodes: $threads}}}}}' >"$tmp/pr.json"
  jq -n --argjson runs "$RUNS" '{total_count: ($runs | length), check_runs: $runs}' >"$tmp/checks.json"
}

# review_comment <login> <open findings> [tier] [sha]: a post-review.sh-shaped comment on $HEAD (or $sha).
review_comment() {
  local tier_line=""
  if [ "${3:-}" = "light" ]; then
    tier_line=$'\nTier: light'
  fi
  local target_sha="${4:-$HEAD}"
  jq -n --arg login "$1" --arg body "$(printf 'Other-family review\n\nReviewed sha: %s\nReviewer: sonnet%s\nOpen findings: %s' "$target_sha" "$tier_line" "$2")" \
    '[{body: $body, author: {__typename: "User", login: $login}}]'
}

# escalation_comment [login] [extra_comments]: an escalation marker comment.
escalation_comment() {
  local login="${1:-me}"
  local extra="${2:-[]}"
  jq -n --arg login "$login" --argjson extra "$extra" \
    '[{body: "Light review escalated\n\nNeeds a normal-tier review of the current head.", author: {__typename: "User", login: $login}}] + $extra'
}

fails=0
# check <name> <expected exit> <codex summary row>
check() {
  write_pr "$3"
  # shellcheck disable=SC2086 # BOT_ARGS is zero or two words on purpose
  out=$(PATH="$tmp/bin:$PATH" FAKE_GH_DIR="$tmp" bash "$SCRIPT" $BOT_ARGS 7 2>&1)
  got=$?
  if [ "$got" -eq "$2" ]; then
    echo "ok: $1 (exit $got)"
  else
    echo "FAIL: $1: want exit $2, got $got"
    echo "$out" | sed 's/^/  /'
    fails=$((fails + 1))
  fi
  reset_knobs
}

check "codex completed on head sha" 0 "$CODEX_OK"
check "codex completed on an older sha" 1 "| **Review** | **Completed** \`${OLD:0:7}\` |"
check "codex completed, no sha" 1 "| **Review** | **Completed** |"
# A running review blocks even when the orchestrator comment passes.
COMMENTS=$(review_comment me 0)
check "codex still running" 1 "| **Review** | **Running** \`${HEAD:0:7}\` |"
# A failed Codex run (usage limit) counts as no Codex review, so the orchestrator comment passes.
COMMENTS=$(review_comment me 0)
check "codex failed, orchestrator comment passes" 0 "| **Review** | **Failed** \`${HEAD:0:7}\` |"
check "codex failed, nothing else" 1 "| **Review** | **Failed** \`${HEAD:0:7}\` |"
# One row still running blocks even when another failed.
COMMENTS=$(review_comment me 0)
check "codex failed and running, orchestrator comment" 1 "$(printf '| **Review** | **Failed** \`%s\` |\n| **Security** | **Running** \`%s\` |' "${HEAD:0:7}" "${HEAD:0:7}")"

RUNS='[{"id": 1, "check_suite": {"id": 1}, "name": "lint", "status": "completed", "conclusion": "failure"}]'
check "failed check run" 1 "$CODEX_OK"

# Two workflows with a job named lint: separate suites, so the newer pass doesn't hide the older failure.
RUNS='[{"id": 1, "check_suite": {"id": 1}, "name": "lint", "status": "completed", "conclusion": "failure"},
  {"id": 2, "check_suite": {"id": 2}, "name": "lint", "status": "completed", "conclusion": "success"}]'
check "same-named run failed in another suite" 1 "$CODEX_OK"

DRAFT=true
check "draft PR" 1 "$CODEX_OK"

THREADS='[{"id": "T1", "isResolved": false, "isOutdated": false, "path": "a.sh", "line": 3, "originalLine": 3,
  "comments": {"nodes": [{"body": "fix this", "author": {"__typename": "Bot", "login": "chatgpt-codex-connector"}}]}}]'
check "unresolved codex thread" 1 "$CODEX_OK"

COMMENTS=$(review_comment me 0)
check "orchestrator comment from me, 0 open" 0 ""
COMMENTS=$(review_comment someone-else 0)
check "orchestrator comment from another login" 1 ""
COMMENTS=$(review_comment me 2)
check "orchestrator comment with open findings" 1 "$CODEX_OK"

# No --bot: the gate ignores bot reviews and threads, and passes on the orchestrator comment alone.
BOT_ARGS=""
check "no bot: a codex summary doesn't count" 1 "$CODEX_OK"
BOT_ARGS=""
COMMENTS=$(review_comment me 0)
check "no bot: orchestrator comment passes" 0 ""
BOT_ARGS=""
COMMENTS=$(review_comment me 0)
THREADS='[{"id": "T1", "isResolved": false, "isOutdated": false, "path": "a.sh", "line": 3, "originalLine": 3,
  "comments": {"nodes": [{"body": "fix this", "author": {"__typename": "Bot", "login": "chatgpt-codex-connector"}}]}}]'
check "no bot: a codex thread doesn't count" 0 "$CODEX_OK"
BOT_ARGS="--bot somebot"
check "unknown bot" 2 "$CODEX_OK"

# Escalated PR: bot completed alone does not clear without a normal review.
COMMENTS=$(escalation_comment)
check "escalated, no review at all, bot completed on head" 1 "$CODEX_OK"

# Escalated PR: bot completed plus orchestrator normal review clears.
COMMENTS=$(escalation_comment me "$(review_comment me 0)")
check "escalated, bot completed on head, plus orchestrator normal review 0 open" 0 "$CODEX_OK"

# Escalated PR: light-tier verdict does not clear.
COMMENTS=$(escalation_comment me "$(review_comment me 0 light)")
check "escalated, only light-tier verdict 0 open on head" 1 ""

# Escalated PR: normal review on an older sha does not clear new head.
COMMENTS=$(escalation_comment me "$(review_comment me 0 normal "$OLD")")
check "escalated, normal review on older sha only" 1 ""

# Not escalated: light-tier verdict clears.
COMMENTS=$(review_comment me 0 light)
check "not escalated, light verdict 0 open on head" 0 ""

# Marker may sit outside the 100-comment window: fail closed, so a bot pass alone doesn't clear.
MORE_COMMENTS=true
check "comment window overflow, bot completed on head" 1 "$CODEX_OK"

[ "$fails" -eq 0 ] || exit 1
