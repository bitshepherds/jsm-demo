# jsm-demo

- [jsm-demo](#jsm-demo)
  - [Why use JSON Schema Manager (JSM)?](#why-use-json-schema-manager-jsm)
- [Quickstart Tutorial](#quickstart-tutorial)
  - [Install JSON Schema Manager](#install-json-schema-manager)
  - [The Registry](#the-registry)


This repo demonstrates how to use `jsm` - the JSON Schema Manager CLI - to build, test, and publish JSON Schemas for an organisation.

## Why use JSON Schema Manager (JSM)?

JSON Schemas make excellent data contracts for data at rest (in Document Databases and Data Lakes), and in motion (APIs and event streams). 

Use JSM to:
* manage a broad spectrum of domain contracts across the organisation in a single place, with consistent naming,flexible namespacing, strict semantic versioning, and a clear audit trail of changes provided by git.
* easily collaborate on the design and testing of JSON Schemas, well before use in production code
* prove that changes to a component's data contracts will not break downstream consumers when deployed
* easily decompose schemas for complex business data into a set of smaller, reusable schemas, with common schemas for reuse across the organisation
* from a single source of truth, publish schemas that target different environments, with each environment having bespoke settings for schema mutability and schema URL prefixes.

For more information, see the [JSON Schema Manager documentation](https://github.com/andyballingall/json-schema-manager).

# Quickstart Tutorial

## Install JSON Schema Manager

Mac or linux:
```bash
brew install jsm
```

Windows:
```bash
TODO
```

Then test that installation succeeded:

```bash
jsm -v
```

## The Registry 
A registry is your source code - a directory containing every JSON Schema, along with related test JSON documents.

Schemas are grouped under a hierarchy of one or more **domain** directories. Under the domain sits *schema family* directories.A schema family targets a specific concept, such as a business entity, an event, or a data object. Under each family are the different versions of the family schema, arranged by semantic version.


