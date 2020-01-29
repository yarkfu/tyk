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
  # Filtering files with 'grep -v' would return a non-zero exit status
  fmt_files=$(
    find . -type f -name "*.go" -not -path "./vendor/*" -print0 \
      | xargs -0 gofmt -l
  )
  if [[ -n $fmt_files ]]; then
    fatal "Run 'gofmt -w' on these files:\n$fmt_files"
  fi

  echo "gofmt is OK!"

  # .goimportsignore is not granular enough to ignore individual files in a given directory.
  # In this case, generated protobuf code in *.pb.go files.
  # Ref: https://godoc.org/golang.org/x/tools/cmd/goimports
  imp_files=$(
    find . -type f -name "*.go" -not -name "*.pb.go" -not -path "./vendor/*" -print0 \
      | xargs -0 goimports -l
  )
  if [[ -n $imp_files ]]; then
    fatal "Run 'goimports -w' on these files:\n$imp_files"
  fi

  echo "goimports is OK!"

  # Build goplugins with -race if latest
  race="-race"
fi

pkgs="$(go list ./...)"

go get -t

export PKG_PATH=$GOPATH/src/github.com/TykTechnologies/tyk

# Build goplugins used in tests
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

  # Build up an array of arguments to pass to 'go test'
  test_args=(
    -v
    "-coverprofile=test.cov"
    "-timeout=$test_timeout"
  )

  # Some tests should not be run with -race.
  # Therefore, test them with penultimate Go version.
  # And test with -race in latest Go version.
  if [[ -n $LATEST_GO && $skip_race == false ]]; then
    test_args+=(-race)
  fi

  show go test "${test_args[@]}" "${tags[@]}" "$pkg" \
    || fatal "go test failed"
  show go vet "${tags[@]}" "$pkg" \
    || fatal "go vet errored"
done
