# jsm-demo <!-- omit in toc -->

[![Licence](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

> [!TIP]
>
> Want to jump right in? Try the [tutorial](docs/tutorial.md)!

## Contents <!-- omit in toc -->

- [Introduction](#introduction)
- [Why use JSON Schema?](#why-use-json-schema)
- [Why use JSON Schema Manager (JSM)?](#why-use-json-schema-manager-jsm)
- [JSM Features](#jsm-features)
- [Learn](#learn)
- [Contributing](#contributing)
- [Maintainers](#maintainers)
- [Licence](#licence)

## Introduction

This repo demonstrates how to use `jsm` - the JSON Schema Manager - a command-line tool that makes it easy to write, test, and publish to multiple environments enterprise-grade JSON Schemas for an organisation's data.

## Why use JSON Schema?

JSON is a ubiquitous data format, easily consumed and produce by languages and data services. JSON Schemas make excellent data contracts for data at rest (e.g. in a database or data lake), or in motion (e.g. in APIs and event streams).

Validation and storage are entirely separate concerns. JSON Schema can form the heart of a portable validation strategy, allowing validation to be performed across your organisation against the same contracts, throughout the software delivery lifecycle:

- **before** system implementation, when refining information concepts (e.g. with [Domain Driven Design](https://en.wikipedia.org/wiki/Domain-driven_design))
- **in test**, to validate that systems produce and consume information correctly, and
- **in production**, to identify and isolate bad data early, minimising its impact on the production estate.

## Why use JSON Schema Manager (JSM)?

Managing JSON Schemas is usually a challange.

- Where do they live, and how do you organise and share them?
- How do you enforce consistency across the organisation?
- How do you easily compose schemas from other simpler schemas?
- How do you test them effectively?
- How do you enforce which version of the JSON Schema standard is used?
- How do you easily change schemas over time as your needs change?
- How do you prove that supposedly 'non breaking' changes are indeed non breaking?
- How do you prevent people from changing published schemas?
- How do you manage JSON Schema publication in different environments?

JSON Schema Maanager (JSM) makes this easy.

## JSM Features

- **Schema Registry** - The registry is a directory in a repo dedicated to your organisation's schemas. JSM imposes strict rules about the folder structure and filenames of schemas and test documents within the registry.
- **Schema Composition** - JSON Schemas are highly-composable. JSM makes it easy to reference schemas from other schemas, even if their locations change later, using the `{{ JSM <schema-key> }}` syntax.
- **Schema IDs and URLs** - The `$id` property of a JSON schema should be the URI where the schema will be located once deployed. But that URI has to differ for each environment. JSM makes this easy with the `{{ ID }}` syntax.
- **Schema Testing** - A badly written JSON schema may validate bad data. JSM provides a framework for testing schemas with both passing and failing JSON documents, so that you can prove your schema offers enterprise-grade validation.
- **Schema Versioning** - JSM enforces semantically versioned schemas. Use JSM in your CI/CD pipeline to prevent changes to already published schemas, and during development, where a supposedly 'non-breaking' minor version change would actually break consumers in production if deployed.
- **Schema Publishing** - Use JSM in your CI/CD pipeline to render distribution versions of your schemas for deployment to different environments.
- **Compliant and Performant** - JSM is written in Go, and can run thousands of tests a second. It uses the [github.com/santhosh-tekuri/jsonschema/v6](https://github.com/santhosh-tekuri/jsonschema/v6) library for JSON Schema validation, which provides 100% compliance for all major versions of the JSON Schema standards.

## Learn

- [Tutorial](docs/tutorial.md) - learn by doing.
- [Decoupled services, data evolution, and semantic versioning](docs/decouple.md) - find out why semantic versioning is so important for JSON Schemas.

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
