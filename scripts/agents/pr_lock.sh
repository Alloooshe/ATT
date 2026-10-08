#!/usr/bin/env bash
# Who holds a PR, as a GitHub label `<kind>:<name>` — visible to every session,
# local or cloud. Two kinds:
#   review  one tech lead per PR. Without it two leads read, comment on and try
#           to merge the same PR. Stale after 3 h (a lead that died mid-review).
#   coder   which coding agent owns (tends) a PR. Every agent pushes as the same
#           GitHub user, so `gh pr list --author @me` is everyone's PRs; without
#           this, several coders would all fix the same review comment. Stale
#           after 24 h, like a claim.
#
#   pr_lock.sh take <PR> <name> [review|coder]    exit 0 = yours; 1 = held by another
#   pr_lock.sh release <PR> <name> [review|coder]
#   pr_lock.sh mine <name> [review|coder]         open PRs this name holds
#   pr_lock.sh list                               open PRs with their holders
#
# Two agents labelling in the same second both see two labels; the lexically
# smaller name keeps the PR and the other backs off.
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/config.sh"
kind="review"
case "${1:-}" in
  take|release) kind="${4:-review}" ;;
  mine) kind="${3:-review}" ;;
esac
[[ "$kind" =~ ^(review|coder)$ ]] || { echo "kind must be review or coder" >&2; exit 2; }
if [[ "$kind" == coder ]]; then STALE_H=24; else STALE_H=3; fi
STALE_H="${TEAM_PR_LOCK_STALE_H:-$STALE_H}"

holders() {  # labels <kind>:* on PR $1, one name per line
  gh pr view "$1" --json labels -q ".labels[].name | select(startswith(\"$kind:\")) | ltrimstr(\"$kind:\")"
}

# REST, not `gh pr edit`: some gh versions fail there with a GraphQL error about
# Projects (classic), and the label silently never lands.
add_label() { gh api -X POST "repos/{owner}/{repo}/issues/$1/labels" -f "labels[]=$2" >/dev/null; }
rm_label()  { gh api -X DELETE "repos/{owner}/{repo}/issues/$1/labels/${2/:/%3A}" >/dev/null 2>&1 || true; }

label_age_h() {  # hours since label <kind>:$2 was last added to PR $1
  local t
  t=$(gh api "repos/{owner}/{repo}/issues/$1/events" --paginate \
        -q "[.[] | select(.event==\"labeled\" and .label.name==\"$kind:$2\")] | last | .created_at // empty")
  [[ -z "$t" ]] && { echo 999; return; }
  echo $(( ( $(date +%s) - $(date -d "$t" +%s) ) / 3600 ))
}

case "${1:-}" in
  take)
    pr="$2"; me="$3"
    for other in $(holders "$pr"); do
      [[ "$other" == "$me" ]] && continue
      if (( $(label_age_h "$pr" "$other") >= STALE_H )); then
        rm_label "$pr" "$kind:$other"
        echo "took over #$pr from stale $kind:$other"
      else
        echo "#$pr held by $other"; exit 1
      fi
    done
    if [[ "$kind" == review ]]; then color=BFD4F2; desc="Tech lead $me is reviewing this PR"
    else color=D4C5F9; desc="Coding agent $me owns this PR"; fi
    gh label create "$kind:$me" --color "$color" --description "$desc" --force >/dev/null 2>&1 || true
    add_label "$pr" "$kind:$me"
    sleep 3
    first=$(holders "$pr" | sort | head -1)
    if [[ "$first" != "$me" ]]; then
      rm_label "$pr" "$kind:$me"
      echo "#$pr taken by $first at the same moment"; exit 1
    fi
    echo "#$pr is yours"
    ;;
  release)
    rm_label "$2" "$kind:$3"
    echo "#$2 released"
    ;;
  mine)
    gh pr list --base "$TEAM_BASE" --state open --label "$kind:$2" --json number -q '.[].number'
    ;;
  list)
    gh pr list --base "$TEAM_BASE" --state open --json number,title,isDraft,labels \
      -q '.[] | "#\(.number)\t\(if .isDraft then "draft" else "ready" end)\t\([.labels[].name | select(startswith("review:") or startswith("coder:"))] | join(",") | if .=="" then "-" else . end)\t\(.title)"'
    ;;
  *)
    sed -n '2,18p' "$0"; exit 2 ;;
esac
