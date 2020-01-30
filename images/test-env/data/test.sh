#!/usr/bin/env bash
set -euxo pipefail

function fatal() {
  printf "%s\n" "$@" >&2
  exit 1
}

if [ -z "${GOPATH:-}" ]; then
  fatal "GOPATH is not defined"
fi

test_timeout=5m

# TODO(jlucktay): add linters

pkgs="$(go list ./...)"

go get -t

export PKG_PATH=$GOPATH/src/github.com/TykTechnologies/tyk

# Build goplugins used in tests
go build -race -o ./test/goplugins/goplugins.so -buildmode=plugin ./test/goplugins \
  || fatal "Building goplugins failed"

for pkg in $pkgs; do
  tags=

  # TODO: Remove skip_race variable after solving race conditions in tests.
  skip_race=0
  if [[ $pkg == *"grpc" ]]; then
    skip_race=1
  elif [[ $pkg == *"goplugin" ]]; then
    tags="-tags=goplugin"
  fi

  # Build up an array of arguments to pass to 'go test'
  test_args=(
    -timeout "$test_timeout"
    -v
  )

  if [ "$skip_race" -eq 0 ]; then
    test_args+=(-race)
  fi

  set -x
  go test "${test_args[@]}" "$tags" "$pkg"
  go vet "$tags" "$pkg"
  { set +x; } &> /dev/null
done
