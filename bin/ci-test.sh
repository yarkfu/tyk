#!/usr/bin/env bash
set -euxo pipefail

test_timeout=5m

# Print a command and execute it
show() {
  echo "$@" >&2
  eval "$@"
}

fatal() {
  printf "%s\n" "$@" >&2
  exit 1
}

if [ -z "${GOPATH:-}" ]; then
  fatal "GOPATH is not defined"
fi

race=""
if [[ -n ${LATEST_GO:-} ]]; then
  fmt_files=$(gofmt -l . | grep -v vendor)
  if [[ -n $fmt_files ]]; then
    fatal "Run 'gofmt -w' on these files:\n$fmt_files"
  fi

  echo "gofmt is OK!"

  imp_files="$(goimports -l . | grep -v vendor)"
  if [[ -n $imp_files ]]; then
    fatal "Run 'goimports -w' on these files:\n$imp_files"
  fi

  echo "goimports is OK!"

  # Run with race if latest
  race="-race"
fi

pkgs="$(go list ./...)"

go get -t

export PKG_PATH=$GOPATH/src/github.com/TykTechnologies/tyk

# build Go-plugin used in tests
go build "$race" -o ./test/goplugins/goplugins.so -buildmode=plugin ./test/goplugins \
  || fatal "Building goplugins failed"

for pkg in $pkgs; do
  tags=()

  # TODO: Remove skip_race variable after solving race conditions in tests.
  skip_race=false
  if [[ $pkg == *"grpc" ]]; then
    skip_race=true
  elif [[ $pkg == *"goplugin" ]]; then
    tags+=("-tags 'goplugin'")
  fi

  race=""

  # Some tests should not be run with -race. Therefore, test them with penultimate Go version.
  # And, test with -race in latest Go version.
  if [[ -n $LATEST_GO && $skip_race == false ]]; then
    race="-race"
  fi

  show go test -v "$race" -timeout "$test_timeout" -coverprofile=test.cov "$pkg" "${tags[@]}" \
    || fatal "go test failed"
  show go vet "${tags[@]}" "$pkg" \
    || fatal "go vet errored"
done
