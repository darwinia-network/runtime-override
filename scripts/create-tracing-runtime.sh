#!/bin/bash

set -e

REPO_PATH="$( cd "$( dirname "$0" )" && cd ../ && pwd )"

NETWORK=$1
NODE_VERSION=$2

import_help() {
  cat << EOF
  Usage:
    create-tracing-runtime.sh <network> <node_version>

  Args:
    network:          Only support pangolin now.
    node_version:     Release node version, such as main or v2.7.0.
EOF
}

if [[ "${NETWORK}" != "pangolin" ]] || [ -z ${NODE_VERSION} ]; then
    echo "The command arguments not correct, please check again."
    import_help
    exit 1
fi

echo "Clean tmp"
sudo rm -rf ${REPO_PATH}/tmp

echo "Fetch runtime branch"
mkdir -p ${REPO_PATH}/tmp
mkdir -p ${REPO_PATH}/wasm/${NETWORK}
mkdir -p ${REPO_PATH}/wasm-digest/${NETWORK}
git clone https://github.com/darwinia-network/darwinia-common -b ${NODE_VERSION} --depth 1 ${REPO_PATH}/tmp/darwinia-common

echo "Create compile workspace"
mkdir -p ${REPO_PATH}/tmp/node/runtime
cp -r -p ${REPO_PATH}/tmp/darwinia-common/node/runtime/${NETWORK} ${REPO_PATH}/tmp/node/runtime
cp -r -p ${REPO_PATH}/tmp/darwinia-common/node/runtime/common ${REPO_PATH}/tmp/node/runtime
cp -r -p ${REPO_PATH}/tmp/darwinia-common/node/primitives ${REPO_PATH}/tmp/node
cp ${REPO_PATH}/tmp/darwinia-common/rust-toolchain.toml ${REPO_PATH}/tmp/node
cp ${REPO_PATH}/scripts/Cargo.toml.template ${REPO_PATH}/tmp/node/Cargo.toml

echo "Replace path dependencites by git dependencites"
sed -i "s/path = \"..\/..\/..\/frame\/[[:print:]]*\"/git = \"https:\/\/github\.com\/darwinia-network\/darwinia-common\", branch = \"${NODE_VERSION}\"/g" \
    ${REPO_PATH}/tmp/node/runtime/${NETWORK}/Cargo.toml \
    ${REPO_PATH}/tmp/node/runtime/common/Cargo.toml \
    ${REPO_PATH}/tmp/node/primitives/bridge/Cargo.toml
sed -i "s/path = \"..\/..\/..\/primitives\/[[:print:]]*\"/git = \"https:\/\/github\.com\/darwinia-network\/darwinia-common\", branch = \"${NODE_VERSION}\"/g" \
     ${REPO_PATH}/tmp/node/runtime/${NETWORK}/Cargo.toml

echo "Enable evm-tracing feature default"
sed -i -e 's/\[\s*"std"\s*\]/\[ "std", "evm-tracing" \]/g' ${REPO_PATH}/tmp/node/runtime/${NETWORK}/Cargo.toml

echo "Add evm patch.crates-io"
cat ${REPO_PATH}/tmp/darwinia-common/Cargo.toml | grep "evm" | tail -n 3 >> ${REPO_PATH}/tmp/node/Cargo.toml

echo "Build tracing runtime"
cd ${REPO_PATH}/tmp/node
cargo update --workspace
CMD="srtool build --package ${NETWORK}-runtime --runtime-dir runtime/${NETWORK} -a -j"

stdbuf -oL $CMD | {
    while IFS= read -r line
    do
        echo ║ $line
        JSON="$line"
    done
    # Copy wasm blob and josn digest in git repository
    WASM=`echo $JSON | jq -r .runtimes.compressed.wasm`
    WASM_VERSION=`echo $JSON | jq -r .runtimes.compressed.subwasm.core_version`
    RUNTIME_VERSION=`echo $WASM_VERSION | cut -d " " -f 1 | cut -d - -f 2`

    cp $WASM ${REPO_PATH}/wasm/${NETWORK}/${NETWORK}-runtime-${RUNTIME_VERSION}-tracing-runtime.wasm
    echo $JSON > ${REPO_PATH}/wasm-digest/${NETWORK}/${NETWORK}-runtime-${RUNTIME_VERSION}-tracing-runtime.json
}
cd ../..

echo "Clean tmp after tracing runtime successfully"
sudo rm -rf ${REPO_PATH}/tmp