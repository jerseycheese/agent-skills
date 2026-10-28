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

# write_pr <codex summary row>: a clean, open PR on $HEAD whose only comment is a Codex summary.
write_pr() {
  local body
  body=$(printf '<!-- codex-pull-request-review-summary -->\n| Task | Status |\n%s' "$1")
  jq -n --arg head "$HEAD" --arg body "$body" '{data: {viewer: {login: "me"}, repository: {pullRequest: {
    state: "OPEN", isDraft: false, mergeable: "MERGEABLE", mergeStateStatus: "CLEAN", headRefOid: $head,
    comments: {nodes: [{body: $body, author: {__typename: "Bot", login: "chatgpt-codex-connector"}}]},
    reviewThreads: {pageInfo: {hasNextPage: false}, nodes: []}}}}}' >"$tmp/pr.json"
}

fails=0
# check <name> <expected exit> <codex summary row>
check() {
  write_pr "$3"
  out=$(PATH="$tmp/bin:$PATH" FAKE_GH_DIR="$tmp" bash "$SCRIPT" 7 2>&1)
  got=$?
  if [ "$got" -eq "$2" ]; then
    echo "ok: $1 (exit $got)"
  else
    echo "FAIL: $1: want exit $2, got $got"
    echo "$out" | sed 's/^/  /'
    fails=$((fails + 1))
  fi
}

check "codex completed on head sha" 0 "| **Review** | **Completed** \`${HEAD:0:7}\` |"
check "codex completed on an older sha" 1 "| **Review** | **Completed** \`${OLD:0:7}\` |"
check "codex completed, no sha" 1 "| **Review** | **Completed** |"

[ "$fails" -eq 0 ] || exit 1
