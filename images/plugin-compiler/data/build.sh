#!/usr/bin/env bash
set -euxo pipefail

# This directory will contain the plugin source and will be
# mounted from the host box by the user using docker volumes
PLUGIN_BUILD_PATH=/go/src/plugin-build

function usage() {
  cat << EOF
To build a plugin:
      $0 <plugin_name>

EOF
}

if [ -z "${1:-}" ]; then
  usage
  exit 1
else
  plugin_name=$1
fi

# Handle if plugin has own vendor folder, and ignore error if not
cp -fr "$PLUGIN_BUILD_PATH/vendor" "${GOPATH:?}/src" || true \
  && rm -rf "$PLUGIN_BUILD_PATH/vendor"

cd "$PLUGIN_BUILD_PATH" \
  && go build -buildmode=plugin -o "$plugin_name"
