#!/usr/bin/env bash
# pr-ready.sh <pr-number>
#
# One call that answers "is this PR ready to merge?" for the review gate. Prints at most 6 lines
# and exits 0 only when every line passes. Exit 1 means not ready, exit 2 means it couldn't tell
# (bad argument, gh failure); callers that gate a merge on this should treat both as a stop.
#
# Run it from a checkout of the repo; owner/repo come from the git remote (or GH_REPO).
# Needs only `gh`, authenticated, bash 3.2 or newer.
#
# What counts, and why:
# - CI: the newest check run per check suite and check name on the head sha, plus commit
#   statuses. A re-run stays in its workflow run's check suite, so it replaces the run it re-ran;
#   two workflows with a job of the same name are separate suites, so both count. No checks
#   reported yet is pending, not a pass or a failure.
# - Review: passes on either of two sources. Which reviewer a repo uses, and in what order, is the
#   adapter's call, not this script's.
#   - Codex: the summary marker comment exists, every row of its table says Completed, and the sha
#     it names is the head (prefix match, since the table can carry a short sha). The bot reviews
#     when a PR opens, is marked ready, or is asked to (@codex review), not on every push, so a
#     summary on an older sha is stale and doesn't pass, and neither does one that names no sha.
#     A summary that's posted but not Completed means the review is still running, and that
#     blocks even if the other source passes.
#   - Orchestrator comment: the other-family review is a comment the orchestrator posts with
#     post-review.sh, from the account gh is signed in as. The newest such comment naming the
#     head sha decides: it passes at "Open findings: 0". The comment has to start with the
#     "Other-family review" line and carry full-sha, Reviewer and Open findings lines, the shape
#     post-review.sh writes. A comment that names an older sha is stale (a push landed after the
#     review). Comments from anyone else are ignored, so nobody else can forge a pass.
#     A comment on the head with open findings blocks even when the other source passes.
# - Findings: every inline thread Codex started that is still unresolved, whichever source passed.
#   An outdated one (a push changed the commented lines) is flagged, not dropped: GitHub marks a
#   thread outdated whether or not the push fixed it, and the bot doesn't re-review, so a thread
#   only clears when someone verifies the fix (or that the finding isn't real) and resolves it.
#   Each finding carries its thread id for resolve-thread.sh, which is the narrow way to do that.
# - The bot is matched by exact login and the Bot account type, so a lookalike account can't forge
#   the summary or a finding.

set -u
set -o pipefail

CODEX_LOGIN="chatgpt-codex-connector"
SUMMARY_MARKER="<!-- codex-pull-request-review-summary -->"
FINDING_CHARS=120

die() {
  echo "pr-ready: $*" >&2
  exit 2
}

pr="${1:-}"
case "$pr" in
  '' | *[!0-9]*) die "usage: pr-ready.sh <pr-number>" ;;
esac

repo=$(gh api 'repos/{owner}/{repo}' --jq .full_name) || die "can't resolve owner/repo"
owner="${repo%%/*}"
name="${repo#*/}"

# gojq (inside gh --jq) prints strings raw; each output line is TAB-separated, with no empty fields.
pr_jq='
def codex: .author.__typename == "Bot" and .author.login == "'"$CODEX_LOGIN"'";
def line($re): map(select(test($re))) | .[0];
def review:
  (.body | split("\n")) as $l
  | ($l | line("^Reviewed sha: [0-9a-f]{40}[ ]*$")) as $s
  | ($l | line("^Open findings: [0-9]+[ ]*$")) as $o
  | ($l | line("^Reviewer: [^ ].*$")) as $r
  | if $l[0] != "Other-family review" or $s == null or $o == null or $r == null then empty
    else {sha: ($s | capture("(?<x>[0-9a-f]{40})").x),
          open: ($o | capture("(?<n>[0-9]+)").n | tonumber),
          who: ($r | sub("^Reviewer: "; "") | sub("[ ]+$"; ""))}
    end;
.data.viewer.login as $me
| .data.repository.pullRequest
| .headRefOid as $head
| "head\t\(.headRefOid)",
  "state\t\(.state)",
  "draft\t\(.isDraft)",
  "merge\t\(.mergeable)\t\(.mergeStateStatus)",
  ( [.comments.nodes[] | select(codex and (.body | contains("'"$SUMMARY_MARKER"'")))] | last // null
    | if . == null then "summary\tnone\t-"
      else (.body | split("\n") | map(select(startswith("| ") and contains("**")))) as $rows
        | "summary\t\(if ($rows | length) > 0 and ($rows | all(contains("**Completed**"))) then "complete" else "running" end)\t\(([$rows[] | capture("`(?<s>[0-9a-f]{7,40})`") | .s] | last) // "-")"
      end ),
  ( [.comments.nodes[] | select(.author.login == $me) | review] as $revs
    | ([$revs[] | select(.sha == $head)] | last) as $cur
    | if $cur != null then "review\tcurrent\t\($cur.sha[0:10])\t\($cur.open)\t\($cur.who)"
      elif ($revs | length) > 0 then "review\tstale\t\($revs | last | .sha[0:10])\t0\t-"
      else "review\tnone\t-\t0\t-" end ),
  "threads\t\(.reviewThreads.pageInfo.hasNextPage)",
  ( .reviewThreads.nodes[]
    | select((.isResolved | not) and (.comments.nodes[0] | codex))
    | .comments.nodes[0].body as $b
    | "finding\t\(.path):\(.line // .originalLine)\t\((($b | capture("!\\[(?<p>P[0-9]+) Badge\\]") | .p) // "P?"))\t\(.id)\t\(if .isOutdated then "(outdated) " else "" end)\($b | split("\n")[0] | gsub("<[^>]*>|!\\[[^\\]]*\\]\\([^)]*\\)|\\*\\*"; "") | gsub("^\\s+|\\s+$"; "") | .[0:'"$FINDING_CHARS"'])" )
'

pr_query='
query($owner: String!, $name: String!, $num: Int!) {
  viewer { login }
  repository(owner: $owner, name: $name) {
    pullRequest(number: $num) {
      state isDraft mergeable mergeStateStatus headRefOid
      comments(last: 100) { nodes { body author { __typename login } } }
      reviewThreads(first: 100) {
        pageInfo { hasNextPage }
        nodes {
          id isResolved isOutdated path line originalLine
          comments(first: 1) { nodes { body author { __typename login } } }
        }
      }
    }
  }
}'

pr_lines=$(gh api graphql -f owner="$owner" -f name="$name" -F num="$pr" -f query="$pr_query" --jq "$pr_jq") \
  || die "can't read PR #$pr in $repo"

head_sha="" pr_state="" is_draft="" mergeable="" merge_state="" summary="none" summary_sha="-" threads_more="false"
rev_state="none" rev_sha="-" rev_open=0 rev_who="-" review_blocked="" comment_why=""
findings=""
finding_count=0
while IFS=$'\t' read -r key f1 f2 f3 f4; do
  case "$key" in
    head) head_sha="$f1" ;;
    state) pr_state="$f1" ;;
    draft) is_draft="$f1" ;;
    merge) mergeable="$f1" merge_state="$f2" ;;
    summary) summary="$f1" summary_sha="$f2" ;;
    review) rev_state="$f1" rev_sha="$f2" rev_open="$f3" rev_who="$f4" ;;
    threads) threads_more="$f1" ;;
    finding)
      finding_count=$((finding_count + 1))
      if [ -n "$findings" ]; then findings="$findings | "; fi
      findings="$findings$f1 $f2 $f3 $f4"
      ;;
  esac
done <<<"$pr_lines"
[ -n "$head_sha" ] || die "no head sha for PR #$pr in $repo"

ci_jq='
(if .total_count > (.check_runs | length) then "overflow\t-" else empty end),
(.check_runs | group_by([.check_suite.id, .name])[] | max_by(.id)
  | "\(if .status != "completed" then "pending" elif (.conclusion | IN("success", "neutral", "skipped")) then "pass" else "fail" end)\t\(.name)")'
status_jq='
.statuses[]
| "\(if .state == "success" then "pass" elif .state == "pending" then "pending" else "fail" end)\t\(.context)"'

ci_lines=$(gh api "repos/$repo/commits/$head_sha/check-runs?filter=all&per_page=100" --jq "$ci_jq") \
  || die "can't read check runs for $head_sha"
status_lines=$(gh api "repos/$repo/commits/$head_sha/status" --jq "$status_jq") \
  || die "can't read commit statuses for $head_sha"

ci_total=0 ci_failed="" ci_pending="" ci_overflow=0
while IFS=$'\t' read -r state check; do
  [ -n "$state" ] || continue
  case "$state" in
    overflow) ci_overflow=1 ;;
    fail)
      ci_total=$((ci_total + 1))
      ci_failed="${ci_failed:+$ci_failed, }$check"
      ;;
    pending)
      ci_total=$((ci_total + 1))
      ci_pending="${ci_pending:+$ci_pending, }$check"
      ;;
    pass) ci_total=$((ci_total + 1)) ;;
  esac
done <<<"$ci_lines
$status_lines"

ready=1

if [ -n "$ci_failed" ]; then
  ci_out="fail ($ci_failed)"
  ready=0
elif [ "$ci_overflow" -eq 1 ]; then
  ci_out="unknown (more than 100 check runs)"
  ready=0
elif [ -n "$ci_pending" ]; then
  ci_out="pending ($ci_pending)"
  ready=0
elif [ "$ci_total" -eq 0 ]; then
  ci_out="pending (no checks reported)"
  ready=0
else
  ci_out="pass (n=$ci_total)"
fi

if [ "$is_draft" = "true" ]; then
  draft_out="yes"
  ready=0
else
  draft_out="no"
fi

codex_ok=0 codex_why=""
case "$summary" in
  complete)
    case "$summary_sha" in
      -) codex_why="codex summary names no sha" ;;
      *)
        case "$head_sha" in
          "$summary_sha"*) codex_ok=1 ;;
          *) codex_why="stale (codex reviewed ${summary_sha}, head is ${head_sha:0:10})" ;;
        esac
        ;;
    esac
    ;;
  running) review_blocked="codex review still running" ;;
esac

comment_ok=0
case "$rev_state" in
  current)
    if [ "$rev_open" -eq 0 ]; then
      comment_ok=1
    else
      comment_why="${rev_open} open on ${rev_sha} by ${rev_who}"
      review_blocked="$comment_why"
    fi
    ;;
  stale) comment_why="stale (reviewed ${rev_sha}, head moved)" ;;
esac

if [ -n "$review_blocked" ]; then
  review_out="$review_blocked"
  ready=0
elif [ "$codex_ok" -eq 1 ]; then
  review_out="codex summary completed on ${summary_sha}"
elif [ "$comment_ok" -eq 1 ]; then
  review_out="comment on ${rev_sha} by ${rev_who}, 0 open"
else
  review_out="${comment_why:-${codex_why:-not posted}}"
  ready=0
fi

if [ "$threads_more" = "true" ]; then
  findings_out="unknown (more than 100 review threads)"
  ready=0
elif [ "$finding_count" -gt 0 ]; then
  findings_out="$finding_count unresolved: $findings"
  ready=0
else
  findings_out="none"
fi

if [ "$pr_state" != "OPEN" ]; then
  merge_out="n/a, PR is $pr_state"
  ready=0
else
  merge_out="$mergeable ($merge_state)"
  case "$mergeable/$merge_state" in
    MERGEABLE/CLEAN | MERGEABLE/HAS_HOOKS) ;;
    *) ready=0 ;;
  esac
fi

echo "head: $head_sha"
echo "ci: $ci_out"
echo "draft: $draft_out"
echo "review: $review_out"
echo "findings: $findings_out"
echo "mergeable: $merge_out"

[ "$ready" -eq 1 ]
