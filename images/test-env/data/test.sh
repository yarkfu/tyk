#!/usr/bin/env bash
set -euxo pipefail

if [ -z "${GOPATH:-}" ]; then
  fatal "GOPATH is not defined"
fi

test_timeout=5m

# TODO(jlucktay): add linters

cd /go/src/github.com/TykTechnologies/tyk

pkgs="$(go list ./...)"

go get -t

for pkg in $pkgs; do
  tags=

  if [[ $pkg == *"goplugin" ]]; then
    tags="-tags=goplugin"
  fi

  test_args=(
    -coverprofile test.cov
    -timeout "$test_timeout"
    -v
  )

  set -x
  go test "${test_args[@]}" "$tags" "$pkg"
  go vet "$tags" "$pkg"
  { set +x; } &> /dev/null
done
