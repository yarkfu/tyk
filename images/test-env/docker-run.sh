#!/usr/bin/env bash
set -euo pipefail

tyk_path=/go/src/github.com/TykTechnologies/tyk

docker run \
  --interactive \
  --rm \
  --tty \
  --volume "$HOME$tyk_path:$tyk_path" \
  tyk-gateway-test
