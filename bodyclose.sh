#!/usr/bin/env bash
set -euo pipefail
shopt -s globstar nullglob
IFS=$'\n\t'

script_dir="$(cd "$(dirname "${BASH_SOURCE[-1]}")" &> /dev/null && pwd)"
sha=093d88fb259128c2aa4097627c071c29c9042994

# Run git commands in this repo
function gitdw() {
  git --git-dir="$script_dir/.git" --work-tree="$script_dir" "$@"
}

# Get last build state from Travis
function build_state() {
  curl \
    --header "Authorization: token $(grep access_token "$HOME/.travis/config.yml" | cut -d':' -f2 | xargs)" \
    --header "Travis-API-Version: 3" \
    --silent \
    https://api.travis-ci.org/repo/TykTechnologies%2Ftyk/branch/fix%2F2831%2Freload-leaks-memory \
    | jq --raw-output --sort-keys '.last_build.state'
}

# Don't start a new loop if the last one didn't pass
if [ "$(build_state)" != "passed" ]; then
  echo "The previous build did not pass!"
  exit 1
fi

while true; do
  # Apply diffs from this commit until the repo gets dirty
  for altered_file in $(gitdw diff-tree --no-commit-id --name-only -r "$sha"); do
    echo "file: '$altered_file'"
    patch=$(gitdw show --patch "$sha" -- "$altered_file")

    # Restart the loop if the patch doesn't apply cleanly
    if ! gitdw apply --ignore-space-change --ignore-whitespace --whitespace=fix <<< "$patch"; then
      continue
    fi

    # If the patch applied successfully, and the repo is now dirty, add+commit+push
    if ! gitdw diff-index --quiet HEAD --; then
      gitdw add "$altered_file"
      gitdw commit -m"Add bodyclose changes for '$altered_file'."
      gitdw push
      break
    fi
  done

  # Start watching Travis, after giving it a chance to start the next run
  sleep 30s

  while [ "$(build_state)" == "started" ]; do
    date
    sleep 5s
  done

  state=$(build_state)

  echo
  echo "State of last build: '$state'"
  echo

  if [ "$state" != "passed" ]; then
    exit 1
  fi
done
