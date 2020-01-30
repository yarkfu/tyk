#!/usr/bin/env bash
set -euo pipefail

docker build \
  --tag tyk-gateway-test \
  .
