# Darwinia Runtime Overrides

Inspired by [Moonbeam Runtime Overrives](https://github.com/PureStake/moonbeam-runtime-overrides)

### Install srtool

```sh
$ cargo install --git https://github.com/chevdor/srtool-cli
```

## Usage

```sh
$ ./scripts/create-tracing-runtime.sh --help
  Usage:
    create-tracing-runtime.sh <network> <node_version> <runtime_version>

  Args:
    network:          Only support pangolin now.
    node_version:     Node release version, such as v2.7.0.
    runtime_version:  Runtime release version, such as 27000.
```

Example:

```sh
$ /scripts/create-tracing-runtime.sh pangolin v2.7.2 27200
```

