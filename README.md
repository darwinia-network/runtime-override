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
    create-tracing-runtime.sh <network> <node_version>

  Args:
    network:          Only support pangolin now.
    node_version:     Node release version, such as main or v2.7.0.
```

Example:

```sh
$ /scripts/create-tracing-runtime.sh pangolin main
```

