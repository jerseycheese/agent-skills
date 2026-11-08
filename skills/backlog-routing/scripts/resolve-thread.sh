#!/usr/bin/env bash
# resolve-thread.sh --bot <name> <thread-id> <commit-sha>
#
# Clears one verified review-bot thread: replies on it pointing at the commit, then resolves it.
# --bot names the bot whose threads it may touch, the same profile pr-ready.sh takes (bundled:
# codex, the Codex GitHub connector).
# Use it after checking the finding yourself. For a finding that isn't real, pass the head sha you
# verified against. The thread id is on the `findings` line of pr-ready.sh. Reviews the
# orchestrator posts as a comment have no thread; post-review.sh covers those.
#
# Narrow on purpose, so an agent can be allowed to run it without being allowed to run arbitrary
# `gh api graphql`. It refuses unless all of these hold:
# - the thread id is a review thread in this repo, on an open PR
# - the thread was started by that bot (exact login and the Bot account type)
# - the commit exists in this repo
# An already-resolved thread is a no-op that exits 0.
#
# Exit 0: resolved, or already resolved. Exit 1: refused. Exit 2: bad argument or gh failure.
# Run it from a checkout of the repo (or with GH_REPO set). Needs only `gh`, bash 3.2 or newer.

set -u
set -o pipefail

die() {
  echo "resolve-thread: $*" >&2
  exit 2
}

refuse() {
  echo "resolve-thread: refused: $*" >&2
  exit 1
}

usage="usage: resolve-thread.sh --bot <name> <thread-id> <commit-sha>"
[ "$#" -eq 4 ] && [ "$1" = "--bot" ] || die "$usage"
bot="$2"
thread="$3"
sha="$4"
# Bot profiles: keep in sync with pr-ready.sh.
case "$bot" in
  codex) BOT_LOGIN="chatgpt-codex-connector" ;;
  *) die "unknown review bot: $bot (bundled: codex)" ;;
esac
[[ "$thread" =~ ^PRRT_[A-Za-z0-9_-]+$ ]] || die "not a review thread id: $thread"
[[ "$sha" =~ ^[0-9a-f]{7,40}$ ]] || die "not a commit sha: $sha"

repo=$(gh api 'repos/{owner}/{repo}' --jq .full_name) || die "can't resolve owner/repo"
full_sha=$(gh api "repos/$repo/commits/$sha" --jq .sha) || die "can't find commit $sha in $repo"

thread_query='
query($id: ID!) {
  node(id: $id) {
    __typename
    ... on PullRequestReviewThread {
      isResolved
      pullRequest { state repository { nameWithOwner } }
      comments(first: 1) { nodes { author { __typename login } } }
    }
  }
}'
thread_jq='
.data.node
| "type\t\(.__typename)",
  "resolved\t\(.isResolved)",
  "prstate\t\(.pullRequest.state)",
  "repo\t\(.pullRequest.repository.nameWithOwner)",
  "author\t\(.comments.nodes[0].author.__typename)\t\(.comments.nodes[0].author.login)"'

thread_lines=$(gh api graphql -f id="$thread" -f query="$thread_query" --jq "$thread_jq") \
  || die "can't read thread $thread"

node_type="" resolved="" pr_state="" thread_repo="" author_type="" author_login=""
while IFS=$'\t' read -r key f1 f2; do
  case "$key" in
    type) node_type="$f1" ;;
    resolved) resolved="$f1" ;;
    prstate) pr_state="$f1" ;;
    repo) thread_repo="$f1" ;;
    author) author_type="$f1" author_login="$f2" ;;
  esac
done <<<"$thread_lines"

[ "$node_type" = "PullRequestReviewThread" ] || refuse "$thread is not a review thread"
[ "$thread_repo" = "$repo" ] || refuse "thread belongs to $thread_repo, not $repo"
[ "$author_type/$author_login" = "Bot/$BOT_LOGIN" ] || refuse "thread wasn't started by $BOT_LOGIN"
[ "$pr_state" = "OPEN" ] || refuse "PR is $pr_state, not OPEN"

if [ "$resolved" = "true" ]; then
  echo "already resolved: $thread"
  exit 0
fi

reply_query='
mutation($thread: ID!, $body: String!) {
  addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $thread, body: $body}) {
    comment { id }
  }
}'
resolve_query='
mutation($thread: ID!) {
  resolveReviewThread(input: {threadId: $thread}) { thread { isResolved } }
}'

short_sha="${full_sha:0:10}"
gh api graphql -f thread="$thread" -f body="Verified against $short_sha. Resolving." -f query="$reply_query" \
  --jq .data.addPullRequestReviewThreadReply.comment.id >/dev/null || die "couldn't reply on $thread; nothing changed"

resolved_now=$(gh api graphql -f thread="$thread" -f query="$resolve_query" \
  --jq .data.resolveReviewThread.thread.isResolved) \
  || die "replied on $thread but couldn't resolve it; don't rerun blindly, it would reply twice"
[ "$resolved_now" = "true" ] || die "replied on $thread but it isn't resolved; don't rerun blindly"

echo "resolved: $thread (replied, pointing at $short_sha)"
