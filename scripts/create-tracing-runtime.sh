#!/bin/bash

set -xe

NETWORK=$1
NODE_VERSION=$2
RUNTIME_VERSION=$3

import_help() {
  cat << EOF
  Usage:
    create-tracing-runtime.sh <network> <node_version> <runtime_version>

  Args:
    network:          Only support pangolin now.
    node_version:     Release node version, such as v2.7.0.
    runtime_version:  Runtime release version.
EOF
}

if [[ "${NETWORK}" != "pangolin" ]] || [ -z ${NODE_VERSION} ] || [ -z ${RUNTIME_VERSION} ]; then
    echo "The command arguments not correct !!!"
    import_help
    exit 1
fi

echo "Clean tmp"
sudo rm -rf tmp

echo "Fetch runtime branch"
mkdir -p tmp
mkdir -p wasm/${NETWORK}
mkdir -p wasm-digest/${NETWORK}
git clone https://github.com/darwinia-network/darwinia-common -b ${NODE_VERSION} --depth 1 tmp/darwinia-common

echo "Create compile workspace"
mkdir -p tmp/node/runtime
cp -r -p tmp/darwinia-common/node/runtime/pangolin tmp/node/runtime
cp -r -p tmp/darwinia-common/node/runtime/common tmp/node/runtime
cp -r -p tmp/darwinia-common/node/primitives tmp/node
cp tmp/darwinia-common/rust-toolchain.toml tmp/node
cp scripts/Cargo.toml.template tmp/node/Cargo.toml

echo "Replace path dependencites by git dependencites"
sed -i "s/path = \"..\/..\/..\/frame\/[[:print:]]*\"/git = \"https:\/\/github\.com\/darwinia-network\/darwinia-common\", branch = \"${NODE_VERSION}\"/g" \
    tmp/node/runtime/pangolin/Cargo.toml \
    tmp/node/runtime/common/Cargo.toml \
    tmp/node/primitives/bridge/Cargo.toml
sed -i "s/path = \"..\/..\/..\/primitives\/[[:print:]]*\"/git = \"https:\/\/github\.com\/darwinia-network\/darwinia-common\", branch = \"${NODE_VERSION}\"/g" \
     tmp/node/runtime/pangolin/Cargo.toml

echo "Enable evm-tracing feature default"
sed -i -e 's/\[\s*"std"\s*\]/\[ "std", "evm-tracing" \]/g' tmp/node/runtime/${NETWORK}/Cargo.toml

echo "Build tracing runtime"
cd tmp/node
cargo update --workspace
CMD="srtool build --package ${NETWORK}-runtime --runtime-dir runtime/${NETWORK} -a -j"

stdbuf -oL $CMD | {
    while IFS= read -r line
    do
        echo ║ $line
        JSON="$line"
    done
    # Copy wasm blob and josn digest in git repository
    Z_WASM=`echo $JSON | jq -r .runtimes.compressed.wasm`
    cp $Z_WASM ../../wasm/${NETWORK}/${NETWORK}-runtime-${RUNTIME_VERSION}-tracing-runtime.wasm
    echo $JSON > ../../wasm-digest/${NETWORK}/${NETWORK}-runtime-${RUNTIME_VERSION}-tracing-runtime.json
}
cd ../..

echo "Clean tmp after tracing runtime successfully"
sudo rm -rf tmp