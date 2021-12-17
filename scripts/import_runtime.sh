#!/bin/bash

SPEC_VERSION=$1

# echo "Fetch pangolin runtime tagged branch"
# mkdir tmp
# git clone https://github.com/darwinia-network/darwinia-common -b bear-dvm-debug --depth 1 tmp/darwinia-common

echo "Copy runtime files"
mkdir -p runtimes/pangolin/${SPEC_VERSION}

cp -r tmp/darwinia-common/node/runtime/pangolin runtimes/pangolin/${SPEC_VERSION}
cp -r tmp/darwinia-common/node/runtime/common runtimes/pangolin/${SPEC_VERSION}
# cp -r tmp/darwinia-common/primitives/evm/trace runtimes/pangolin/${SPEC_VERSION}
cp scripts/Cargo.toml.template runtimes/pangolin/${SPEC_VERSION}/Cargo.toml


echo "Replace path dependencites by git dependencites"