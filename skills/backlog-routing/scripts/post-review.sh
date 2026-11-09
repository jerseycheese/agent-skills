#!/usr/bin/env bash
# post-review.sh [--light] <pr-number> <sha> <open-findings> <reviewer>   (findings text on stdin, optional)
# post-review.sh --escalate <pr-number>
#
# Posts the other-family review of a PR as a comment, in the shape pr-ready.sh reads: a
# `Reviewed sha:` line, a `Reviewer:` line (with an optional `Tier: light` line) and an
# `Open findings:` line. Run it after you've verified each finding the reviewer wrote, so
# the comment holds only the real ones. <open-findings> is how many of those still need a fix.
# A fix push moves the head and makes the comment stale, so the next round posts a new one;
# the newest comment naming the head wins.
#
# With --escalate, posts the marker comment that escalates a light-tier review to a normal review,
# requiring a normal-tier review of the current head before pr-ready.sh clears.
#
# Narrow on purpose, so an agent can be allowed to run it without being allowed to run arbitrary
# `gh pr comment`. It refuses unless all of these hold:
# - the PR is open
# - for a review comment: <sha>, resolved to a full commit id, is the PR's current head (a review
#   of an older commit can't pass the gate)
#
# Exit 0: posted. Exit 1: refused. Exit 2: bad argument or gh failure.
# Run it from a checkout of the repo (or with GH_REPO set). Needs only `gh`, bash 3.2 or newer.

set -u
set -o pipefail

die() {
  echo "post-review: $*" >&2
  exit 2
}

refuse() {
  echo "post-review: refused: $*" >&2
  exit 1
}

if [ "${1:-}" = "--escalate" ]; then
  shift
  [ "$#" -eq 1 ] || die "usage: post-review.sh --escalate <pr-number>"
  pr="$1"
  [[ "$pr" =~ ^[0-9]+$ ]] || die "not a PR number: $pr"
  pr_state=$(gh pr view "$pr" --json state --jq .state) || die "can't read PR #$pr"
  [ "$pr_state" = "OPEN" ] || refuse "PR is $pr_state, not OPEN"
  {
    echo "Light review escalated"
    echo
    echo "Needs a normal-tier review of the current head."
  } | gh pr comment "$pr" --body-file - >/dev/null || die "couldn't post the comment"
  echo "posted: light review escalated"
  exit 0
fi

tier="normal"
if [ "${1:-}" = "--light" ]; then
  tier="light"
  shift
fi

[ "$#" -eq 4 ] || die "usage: post-review.sh [--light] <pr-number> <sha> <open-findings> <reviewer>"
pr="$1"
sha="$2"
open="$3"
reviewer="$4"
[[ "$pr" =~ ^[0-9]+$ ]] || die "not a PR number: $pr"
[[ "$sha" =~ ^[0-9a-f]{7,40}$ ]] || die "not a commit sha: $sha"
[[ "$open" =~ ^[0-9]+$ ]] || die "not a count: $open"
[[ "$reviewer" =~ ^[^[:space:]]([^$'\n\r\t']*[^[:space:]])?$ ]] || die "reviewer must be one non-blank line of plain text"

state_lines=$(gh pr view "$pr" --json state,headRefOid --jq '"\(.state)\t\(.headRefOid)"') \
  || die "can't read PR #$pr"
IFS=$'\t' read -r pr_state head_sha <<<"$state_lines"
[ "$pr_state" = "OPEN" ] || refuse "PR is $pr_state, not OPEN"
full_sha=$(gh api "repos/{owner}/{repo}/commits/$sha" --jq .sha) || die "can't resolve $sha to one commit"
[ "$full_sha" = "$head_sha" ] || refuse "head is ${head_sha:0:10}, not ${full_sha:0:10}; review the current head"

findings=""
if [ ! -t 0 ]; then
  findings=$(cat)
fi

{
  echo "Other-family review"
  echo
  echo "Reviewed sha: $head_sha"
  echo "Reviewer: $reviewer"
  if [ "$tier" = "light" ]; then
    echo "Tier: light"
  fi
  echo "Open findings: $open"
  if [ -n "$findings" ]; then
    echo
    echo "$findings"
  fi
} | gh pr comment "$pr" --body-file - >/dev/null || die "couldn't post the comment"

echo "posted: review of ${head_sha:0:10}, $open open"
