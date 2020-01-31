#!/usr/bin/env bash
set -euo pipefail

function fatal() {
  printf "%s\n" "$@" >&2
  exit 1
}

if [ -z "${GOPATH:-}" ]; then
  fatal "GOPATH is not defined"
fi

test_timeout=5m

# TODO(jlucktay): add linters

if [ -z "$1" ]; then
  fatal "A package path must be specified as the first argument, e.g. 'github.com/TykTechnologies/tyk/gateway'"
fi

if [ -z "$2" ]; then
  fatal "A Go test name must be specified as the second argument, e.g. 'TestAPICertificate/Cert_unknown'"
fi

pkg_name=$1
test_name=$2

echo
printf "Will run test '%s' in the '%s' package.\n" "$test_name" "$pkg_name"
echo
echo "Getting dependencies for tests..."
go get -t -v "$pkg_name"

export PKG_PATH=$GOPATH/src/github.com/TykTechnologies/tyk

echo "Building goplugins used in tests..."
go build -race -o ./test/goplugins/goplugins.so -buildmode=plugin ./test/goplugins \
  || fatal "Building goplugins failed"

tags=

# TODO: Remove skip_race variable after solving race conditions in tests.
skip_race=0
if [[ $pkg_name == *"grpc" ]]; then
  skip_race=1
elif [[ $pkg_name == *"goplugin" ]]; then
  tags="-tags=goplugin"
fi

# Build up an array of arguments to pass to 'go test'
test_args=()

if [ "$skip_race" -eq 0 ]; then
  test_args+=(-race)
fi

test_args+=(
  -run "$test_name"
  -timeout "$test_timeout"
  -v
)

echo "Running test(s)..."
set -x
go test "${test_args[@]}" "$tags" "$pkg_name"
go vet "$tags" "$pkg_name"
{ set +x; } &> /dev/null
