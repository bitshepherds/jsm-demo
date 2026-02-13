# JSON Schema Manager Tutorial <!-- omit in toc -->

- [1. Clone this repo](#1-clone-this-repo)
- [2. Install JSON Schema Manager](#2-install-json-schema-manager)
  - [Installing on macOS or Linux](#installing-on-macos-or-linux)
  - [Installing on Windows](#installing-on-windows)
  - [Test that the install worked](#test-that-the-install-worked)
- [3. Introducing the registry](#3-introducing-the-registry)
  - [Create a new registry](#create-a-new-registry)
  - [Registry configuration](#registry-configuration)
  - [Specifying the registry](#specifying-the-registry)
- [4. Creating Schemas](#4-creating-schemas)
  - [Create a new schema](#create-a-new-schema)
  - [Schema families, versions, and domains](#schema-families-versions-and-domains)
- [5. Developing schemas](#5-developing-schemas)
  - [Define a passing test document](#define-a-passing-test-document)
  - [Update the schema file to define what a valid payment instruction looks like](#update-the-schema-file-to-define-what-a-valid-payment-instruction-looks-like)
- [6. Testing schemas](#6-testing-schemas)
  - [Running tests](#running-tests)
  - [Adding a failing test](#adding-a-failing-test)
- [7. Evolving schemas](#7-evolving-schemas)
  - [Define a passing test document](#define-a-passing-test-document-1)
  - [Run the tests](#run-the-tests)
  - [Update the schema to define the new status property](#update-the-schema-to-define-the-new-status-property)
  - [Run tests when a schema or test document changes](#run-tests-when-a-schema-or-test-document-changes)
- [8. Composing schemas](#8-composing-schemas)

This tutorial will walk you through the features of JSON Schema Manager (JSM).

## 1. Clone this repo

```bash
git clone https://github.com/andyballingall/jsm-demo.git
cd jsm-demo
```

## 2. Install JSON Schema Manager

### Installing on macOS or Linux

> [!TIP]
>
> Don't have Homebrew? First [install it from here](https://brew.sh/).

```bash
brew update
brew install jsm
```

### Installing on Windows

```bash
TODO
```

### Test that the install worked

```bash
jsm -v
```

> [!NOTE]
>
> You can also download the latest release from [GitHub](https://github.com/andyballingall/json-schema-manager/releases).

## 3. Introducing the registry

A registry is a directory - the **registry root directory** - containing the source code for **every version** of your organisation's JSON Schemas, along with their test JSON documents. Like all source code, it should be in a code repository (e.g. GitHub, GitLab, Bitbucket, etc.). We're already in one!

> [!NOTE]
>
> Unlike source code, we need to preserve every version of our schemas, as different components in your organisation will be using different versions of the same schema at the same time. We'll come back to this later.

### Create a new registry

To create a registry called `tutorial`:

```bash
jsm create-registry ./tutorial
```

> [!TIP]
>
> Good names for a production registry might be `src`, `schemas`, or `registry`.

### Registry configuration

A registry's configuration is stored in the `json-schema-manager-config.yml` file in the root directory of the registry. Open that file. The key properties are:

- `defaultJsonSchemaVersion` - defines which version of the JSON Schema standard will be enforced.
- `environments` lets you configure environment-specific settings, including:
  - The URL prefix for public and private schemas deployed to an environment
  - Whether developers can change schemas after deployment (good in `dev`, bad in `prod`!)
  - Which environment is the production environment

You will definitely want to change the `environments` section to match your own requirements, but for now, let's leave it as-is.

### Specifying the registry

Most `jsm` commands operate on a registry. There are two ways to specify it:

1. With the `--registry` or `-r` flag
2. With the `JSM_REGISTRY_ROOT_DIR` environment variable

For now, we'll just use the `-r` flag, but the environment variable makes things easier in the long run.

## 4. Creating Schemas

JSM imposes rules about where schemas and test documents are placed within a registry, and how they are named. This enforces a consistent structure across your organisation, and ensures that it's always easy to find exactly what you are looking for.

To help, JSM includes commands for creating new schemas. Let's take a look.

### Create a new schema

Let's create our first schema in the `tutorial` registry.

```bash
jsm create-schema -r tutorial finance/payments/payment-instruction
```

Take a look inside the `tutorial` directory. What happened there? Let's break it down.

### Schema families, versions, and domains

A schema validates data with a specific purpose, e.g. a payment, an address, or a customer event. Over time, the data will evolve, and so will the schema that validates it. JSM schemas are [semantically versioned](https://semver.org/), and, like any good contract, must be immutable in production.

Every version of a schema which serves the **same** purpose is grouped together in the same **schema family** directory.

> [!NOTE]
>
> Why do we need schema families? See [Decoupled services, data evolution, and semantic versioning](#decoupled-services-data-evolution-and-semantic-versioning).

An organisation might have hundreds or thousands of schema families, so JSM allows you to namespace them by **domain**. Every schema family must be within a domain directory, and you can choose as many levels of domain as you like.

> [!TIP]
>
> We recommend that the top-level domain directories identify departments, teams, or business domains. Sub-domains can be used to further organise schemas.

Putting it all together, the directory structure looks like this:

```text
<registry-root>
  <domain>/                  <-- e.g. a department, team, or business domain
    <sub-domain>/            <-- optional sub-domain (add more if needed)
      <schema-family>/       <-- e.g. payment, address, etc.
        <major-version>/     <--|
          <minor-version>/   <--| Semantic version
            <patch-version>/ <--|
              <SCHEMA-FILE>  <-- THIS IS THE SCHEMA!
              pass/          <-- The test docs that the schema must validate
                <test-doc>
                ...
              fail/          <-- The test docs that the schema must NOT validate
                <test-doc>
                ...
```

Looking again at the command you typed, the last element is always the family name, and all the other elements are domain levels.

```text
jsm create-schema -r tutorial finance/payments/payment-instruction
                              -------/--------/-------------------
                                 |       |            |
                Domain........finance    |            |
                Sub-domain............payments        |
                SCHEMA FAMILY..................payment-instruction

```

This is the structure you can see:

```text
src/
  finance/
    payments/
      payment-instruction/
        1/
          0/
            0/
              finance_payments_payment-instruction_1_0_0.schema.json
              pass/
              fail/
```

> [!NOTE]
>
> The `jsm create-schema` command creates the first schema within a new schema family, and that always has semantic version `1.0.0`.

## 5. Developing schemas

### Define a passing test document

The first step is to create an example of the data that the schema validates. Once we've got that clear, then it's easy to define the schema itself.

Let's create a test document called `all-fields-filled.json`. It belongs in the `pass` directory next to the schema we just created. You can create it with the command:

```bash
touch tutorial/finance/payments/payment-instruction/1/0/0/pass/all-fields-filled.json
```

For this tutorial, let's imagine we're creating a payment instruction schema for a payments system. Paste the following JSON into our new document:

```json
{
  "id": "12345678-1234-5678-1234-567812345678",
  "paymentDate": "2026-02-11T09:18:08Z",
  "amount": 100,
  "currency": "EUR"
}
```

### Update the schema file to define what a valid payment instruction looks like

Open the schema that JSM created for us here:

```text
tutorial/finance/payments/payment-instruction/1/0/0/finance_payments_payment-instruction_1_0_0.schema.json
```

It will look like this:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "{{ ID }}",
  "type": "object",
  "properties": {}
}
```

There are a couple of things to call out:

- `$schema` is the version of the JSON Schema standard defined by the registry config file.
- `$id` in JSON Schema represents the canonical URL for the schema - I.e. the URL that services use to load the schema in an environment. Always leave it set to `{{ ID }}`. JSM will automatically replace it when it creates a distribution version for a target environment. (See `jsm build-dist` below).

Other than that, it's a standard JSON Schema.

> [!TIP]
>
> You can find out more about JSON Schema at [json-schema.org](https://json-schema.org/).

Ok, let's update this schema to validate our passing test document. Usually, you would use AI to quickly get started, then refine it, but for now, just use this example:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "{{ ID }}",
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "paymentDate": {
      "type": "string",
      "format": "date-time"
    },
    "amount": {
      "type": "number"
    },
    "currency": {
      "type": "string",
      "pattern": "^[A-Z]{3}$"
    }
  },
  "required": ["id", "paymentDate", "amount", "currency"]
}
```

## 6. Testing schemas

### Running tests

`jsm validate` is the command used to test one or more schemas in a registry. There are a lot of ways you can use it, but for now, just type:

```bash
jsm validate -v -r tutorial finance/payments/payment-instruction/1/0/0
```

> [!TIP]
>
> Type `jsm validate --help` to see all the options available for the `validate` command.

With the `-v` flag, JSM will tell us which test documents it tried to validate with which schemas. In our case, it tested `finance_payments_payment-instruction_1_0_0.schema.json` against `all-fields-filled.json` and found that it passed.

### Adding a failing test

It isn't enough to know that a schema validates the documents we expect. We also need to know that it rejects documents that it shouldn't pass. That's the job of the `fail` directory.

Let's create a failing test document. Each failing test document should be identical to a passing document, except for a single change that makes it invalid. The name of the file identifies what is wrong.

Let's simulate a scenario where the amount is zero:

```bash
cp tutorial/finance/payments/payment-instruction/1/0/0/pass/all-fields-filled.json tutorial/finance/payments/payment-instruction/1/0/0/fail/amount-zero.json
```

Now, let's update it so amount is zero:

```json
{
  "id": "12345678-1234-5678-1234-567812345678",
  "paymentDate": "2026-02-11T09:18:08Z",
  "amount": 0,
  "currency": "EUR"
}
```

Now, let's run the tests again:

```bash
jsm validate -v -r tutorial finance/payments/payment-instruction/1/0/0
```

The test fails, and for our failing test document, it reports `passed, when expected fail`. This is exactly what we want to see. Our failing test has exposed a flaw in our JSON Schema!

Let's take a look at it, specifically the `amount` property definition:

```json
    "amount": {
      "type": "number"
    },
```

Currently, any number is admissable. This is wrong. Let's try to fix it:

```json
    "amount": {
      "type": "number",
      "exclusiveMinimum": 0
    },
```

Once you've saved it, rerun the tests for this schema:

```bash
jsm validate -v -r tutorial finance/payments/payment-instruction/1/0/0
```

It passes! And next to our failing test, it reports `failed, as expected`. Our failing test is showing that when our schema is asked to validate a document containing that flaw, it will reject it.

Usually, you would create many failing tests to cover all the ways the data could be broken, but we'll move on to the next topic. Two things to bear in mind:

> [!TIP]
>
> If you find a flaw in your schema later after deployment to a non-production environment, and your registry config (`json-schema-manager-config.yml`) has `allowSchemaMutation: true` for that environment, then you can simply update the schema file and redeploy it.

> [!WARNING]
>
> If `allowSchemaMutation` is `false` for an environment, or you have deployed to production, then you will need to create a new version of the schema.

## 7. Evolving schemas

Imagine that we have already deployed our schema to production. This means we **must not** make any changes to that version. But now, the finance team want to add a new `status` property to support a statusis feature.

Usually, it's possible to add new properties to a data document without breaking existing consumers of that data which are using an earlier schema for validation. In semantic versioning, this is an example of a **minor** change.

So we want create a new schema within our schema family. You can do this manually, but the best way is to use the `jsm create-schema-version` command. Let's do that now.

```bash
jsm create-schema-version -r tutorial finance/payments/payment-instruction minor
```

This did the following for you:

1. Worked out what the next version should be - `1.1.0` in this case.
2. Created the new directories
3. Worked out the **precursor** schema. This is the schema to use as a starting point for the changes you want to make in the new version
4. Copied the precursor schema to a new version directory, with the correct new filename.
5. Copied the pass and fail test documents from the precursor schema to the new version.

Cool! Now let's make some changes to the new version we just created. It's the same process as before...

### Define a passing test document

The command we ran already copied `all-fields-filled.json`. You'll find the new version in `tutorial/finance/payments/payment-instruction/1.1.0/pass/all-fields-filled.json`.

Let's augment it with a status property:

```json
{
  "id": "12345678-1234-5678-1234-567812345678",
  "paymentDate": "2026-02-11T09:18:08Z",
  "amount": 100,
  "currency": "EUR",
  "status": "pending"
}
```

### Run the tests

Just like before, we can run the tests for this new schema version:

```bash
jsm validate -v -r tutorial finance/payments/payment-instruction/1/1/0
```

The tests passed, even though we added a new property to the passing test document. This isn't surprising, because the precursor schema didn't set `additionalProperties: false`, so it doesn't care if it sees a property it doesn't know about. This is a good thing, because it means if a consumer using an earlier version of our schema sees that data, it will still validate and not break the consumer.

### Update the schema to define the new status property

Open `tutorial/finance/payments/payment-instruction/1.1.0/finance_payments_payment-instruction_1_1_0.schema.json` and add the following property definition:

```json
    "status": {
      "type": "string",
      "enum": [
        "pending",
        "completed",
        "failed"
      ]
    }
```

### Run tests when a schema or test document changes

To save us having to run the tests each time, we can use the `--watch` or `-w` flag to automatically run tests when a schema or test document changes:

```bash
jsm validate -w -v -r tutorial finance/payments/
```

## 8. Composing schemas

The data that JSON Schema is used to validate is often highly structured and complex, especially in enterprise situations. Additionally, the same sub-structures are often used many times in different schemas. Simple examples might be addresses, or the specific format of a customer-facing ID, but for our schema example, let's imagine we want to capture the location of the device that generated the payment instruction.

