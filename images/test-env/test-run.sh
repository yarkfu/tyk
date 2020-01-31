#!/usr/bin/env bash
set -euo pipefail

function fatal() {
  printf "%s\n" "$@" >&2
  exit 1
}

if [ -z "${1:-}" ]; then
  fatal "A package path must be specified as the first argument, e.g. 'github.com/TykTechnologies/tyk/gateway'"
fi

if [ -z "${2:-}" ]; then
  fatal "A Go test name must be specified as the second argument, e.g. 'TestAPICertificate/Cert_unknown'"
fi

export ATHENS_STORAGE=/tmp/athens-storage

mkdir -p "$ATHENS_STORAGE"

docker-compose build --compress --force-rm

docker-compose run --rm tyk-gateway-test-env "$1" "$2"
