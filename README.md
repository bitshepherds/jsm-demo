# jsm-demo <!-- omit in toc -->

[![Licence](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

A schema is a contract, and how it is used decides which changes to it are safe. Adding a field to an API response harms no one who reads it, but making a field required in a request breaks every client that leaves it out. JSM, the [JSON Schema Manager](https://github.com/bitshepherds/json-schema-manager), knows how each of your schemas is used. It runs your test documents across versions in the direction that use protects, and refuses a change that would break a reader or a writer, before it reaches production. This repo shows it working on a small example you can run in a few minutes.

## Contents <!-- omit in toc -->

- [Quick start](#quick-start)
- [Installing JSM for your own work](#installing-jsm-for-your-own-work)
- [What's here](#whats-here)
- [Contributing](#contributing)
- [Maintainers](#maintainers)
- [Licence](#licence)

## Quick start

You need [Go](https://go.dev/dl/) 1.27.3 or later, and nothing else: this repo pins JSM in `go.mod`, and `go tool jsm` fetches and runs that version the first time you use it.

```sh
git clone https://github.com/bitshepherds/jsm-demo.git
cd jsm-demo
go tool jsm --version
go tool jsm -r registry validate all -C
```

The last command checks every schema in the registry, and ends with `0 failed`. `-r registry` says where the registry is, and `-C` keeps going after a failure, so that you see every result.

Then follow the walk-through, [Getting started: break and fix an API contract](docs/getting-started.md). In about fifteen minutes, you make the same change to an order API's request and its response. JSM passes it on one, refuses it on the other, and says why. Then you fix it.

> [!WARNING]
>
> Until [bitshepherds/json-schema-manager#158](https://github.com/bitshepherds/json-schema-manager/issues/158) is fixed, an exported `JSM_REGISTRY_ROOT_DIR` overrides the current folder. Either unset it, or always pass `-r`, as every command in this repo does.

## Installing JSM for your own work

To use JSM on your own schemas, install it with Go, then check its version:

```sh
go install github.com/bitshepherds/json-schema-manager/v2/cmd/jsm@latest
jsm --version
```

Or pin it in your own repo's `go.mod`, as this one does, and run it as `go tool jsm`:

```sh
go get -tool github.com/bitshepherds/json-schema-manager/v2/cmd/jsm@latest
```

JSM's [user docs](https://github.com/bitshepherds/json-schema-manager/tree/v2.0.0/user-docs) explain the registry, the scenarios, and every command.

## What's here

- [`registry/`](registry/): the demo's schema registry. It holds an order API's request and response, each with versions `1.0.0` and `1.1.0` and their test documents.
- [`docs/getting-started.md`](docs/getting-started.md): the walk-through. Every step in it is replayed on each change to this repo by [`scripts/replay-getting-started.sh`](scripts/replay-getting-started.sh), so it stays true.

## Contributing

We welcome contributions of any kind, but please follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Maintainers

This project is jointly owned by:

- Andy Ballingall
- Bit Shepherds Limited

> [!TIP]
>
> If you'd like to help with the development of JSM itself (i.e. the `jsm` CLI tool), head over to [github.com/bitshepherds/json-schema-manager](https://github.com/bitshepherds/json-schema-manager).

## Licence

This project is licensed under the terms of the [Apache License 2.0](https://opensource.org/licenses/Apache-2.0).
