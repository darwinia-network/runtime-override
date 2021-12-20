#!/bin/bash

set -e

SPEC_VERSION=$1
# TAG_VERSION=$2

echo "Clean tmp"
# sudo rm -rf tmp

# echo "Fetch pangolin runtime tagged branch"
# mkdir tmp
# git clone https://github.com/darwinia-network/darwinia-common -b main --depth 1 tmp/darwinia-common

# echo "Create compile workspace"
# mkdir -p tmp/node/runtime/common tmp/node/primitives

# cp -r -p tmp/darwinia-common/node/runtime/pangolin tmp/node/runtime
# cp -r -p tmp/darwinia-common/node/runtime/common tmp/node/runtime
# cp -r -p tmp/darwinia-common/node/primitives tmp/node
# cp tmp/darwinia-common/rust-toolchain.toml tmp/node
# cp scripts/Cargo.toml.template tmp/node/Cargo.toml

# echo "Replace path dependencites by git dependencites"
# sed -i 's/path = \"..\/..\/..\/frame\/[[:print:]]*\"/git = \"https:\/\/github\.com\/darwinia-network\/darwinia-common\", branch = \"main\"/g' \
#     tmp/node/runtime/pangolin/Cargo.toml \
#     tmp/node/runtime/common/Cargo.toml \
#     tmp/node/primitives/bridge/Cargo.toml
# sed -i 's/path = \"..\/..\/..\/primitives\/[[:print:]]*\"/git = \"https:\/\/github\.com\/darwinia-network\/darwinia-common\", branch = \"main\"/g' \
#      tmp/node/runtime/pangolin/Cargo.toml

# echo "Enable evm-tracing feature default"
# sed -i -e 's/\[\s*"std"\s*\]/\[ "std", "evm-tracing" \]/g' tmp/node/runtime/pangolin/Cargo.toml

echo "Build tracing runtime"
cd tmp/node
cargo update --workspace
CMD="srtool build --package pangolin-runtime --runtime-dir runtime/pangolin -a -j"

stdbuf -oL $CMD | {
    while IFS= read -r line
    do
        echo ║ $line
        JSON="$line"
    done
    # Copy wasm blob and josn digest in git repository
    Z_WASM=`echo $JSON | jq -r .runtimes.compressed.wasm`
    cp $Z_WASM ../../wasm/pangolin/pangolin-runtime-100-substitute-tracing.wasm
    echo $JSON > ../../wasm-digest/pangolin/pangolin-runtime-100-substitute-tracing.json
}
cd ../..

echo "Clean tmp after build runtime"
sudo rm -rf tmp