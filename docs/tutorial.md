# JSON Schema Manager Tutorial <!-- omit in toc -->

This tutorial will walk you through the features of JSON Schema Manager (JSM).

- [1. Clone this repo](#1-clone-this-repo)
- [2. Install JSON Schema Manager](#2-install-json-schema-manager)
- [3. Introducing the registry](#3-introducing-the-registry)
- [4. Creating Schemas](#4-creating-schemas)
- [5. Developing schemas](#5-developing-schemas)
- [6. Testing schemas](#6-testing-schemas)
- [7. Evolving schemas](#7-evolving-schemas)
- [8. Composing schemas](#8-composing-schemas)
  - [Creating a reusable schema](#creating-a-reusable-schema)
  - [Using a reusable schema](#using-a-reusable-schema)
  - [Updating tests for new schema versions](#updating-tests-for-new-schema-versions)
  - [Testing references to other schemas](#testing-references-to-other-schemas)

## 1. Clone this repo

```bash
git clone https://github.com/bitshepherds/jsm-demo.git
cd jsm-demo
```

## 2. Install JSON Schema Manager

### Installing on macOS or Linux <!-- omit in toc -->

> [!TIP]
>
> Don't have Homebrew? First [install it from here](https://brew.sh/).

```bash
brew update
brew install jsm
```

### Installing on Windows <!-- omit in toc -->

```bash
TODO
```

### Test that the install worked <!-- omit in toc -->

```bash
jsm -v
```

> [!NOTE]
>
> You can also download the latest release from [GitHub](https://github.com/bitshepherds/json-schema-manager/releases).

## 3. Introducing the registry

A registry is a directory - the **registry root directory** - containing the source code for **every version** of your organisation's JSON Schemas, along with their test JSON documents. Like all source code, it should be in a code repository (e.g. GitHub, GitLab, Bitbucket, etc.). We're already in one!

> [!NOTE]
>
> Unlike source code, we need to preserve every version of our schemas, as different components in your organisation will be using different versions of the same schema at the same time. We'll come back to this later.

### Create a new registry <!-- omit in toc -->

To create a registry called `tutorial`:

```bash
jsm create-registry ./tutorial
```

> [!TIP]
>
> Good names for a production registry might be `src`, `schemas`, or `registry`.

### Registry configuration <!-- omit in toc -->

A registry's configuration is stored in the `json-schema-manager-config.yml` file in the root directory of the registry. Let's take a look at it. Open:

```
tutorial/json-schema-manager-config.yml
```

The key properties are:

- `defaultJsonSchemaVersion` - defines which version of the JSON Schema standard will be enforced.
- `environments` - lets you configure environment-specific settings, including:
  - The URL prefix for public and private schemas deployed to an environment
  - Whether developers can change schemas after deployment (good in `dev`, bad in `prod`!)
  - Which environment is the production environment

You will definitely want to change the `environments` section to match your own requirements, but for now, let's leave it as-is.

### Specifying the registry <!-- omit in toc -->

Most `jsm` commands operate on a registry. There are two ways to specify it:

1. With the `--registry` or `-r` flag
2. With the `JSM_REGISTRY_ROOT_DIR` environment variable

We'll use option 2. Set the environment with one of the commands below:

#### Mac and Linux (zsh) <!-- omit in toc -->

```bash
echo "export JSM_REGISTRY_ROOT_DIR=\"$(pwd)/tutorial\"" >> ~/.zshrc && source ~/.zshrc
```

#### Linux (bash) <!-- omit in toc -->

```bash
echo "export JSM_REGISTRY_ROOT_DIR=\"$(pwd)/tutorial\"" >> ~/.bashrc && source ~/.bashrc
```

#### Windows (PowerShell) <!-- omit in toc -->

```powershell
[System.Environment]::SetEnvironmentVariable('JSM_REGISTRY_ROOT_DIR', "$PWD\tutorial", 'User'); $env:JSM_REGISTRY_ROOT_DIR = "$PWD\tutorial"
```

## 4. Creating Schemas

JSM imposes rules about where schemas and test documents are placed within a registry, and how they are named. This enforces a consistent structure across your organisation, and ensures that it's always easy to find exactly what you are looking for.

To help, JSM includes commands for creating new schemas. Let's take a look.

### Create a new schema <!-- omit in toc -->

Let's create our first schema in the `tutorial` registry.

For this tutorial, let's imagine we're developing a new `payment-instruction` data entity for a payments system, and we want a JSON Schema to validate it.

Let's dive in. Run this:

```bash
jsm create-schema finance/payments/payment-instruction
```

Now look inside the `tutorial` directory. To make sense of it, there is a bit of context to understand first.

### Schema families, versions, and domains <!-- omit in toc -->

A schema validates data with a specific purpose, e.g. a payment instruction, an address, or a customer event. Over time, the data will evolve, and so will the schema that validates it. JSM schemas use [semantically versioning](https://semver.org/), and, like any good contract, they are immutable in production.

Every **version** of a schema which serves the **same** purpose is grouped together in the same **schema family** directory.

> [!NOTE]
>
> Why do we need schema families? See [Decoupled services, data evolution, and semantic versioning](./decouple.md).

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

This is the structure the command created:

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

The purpose of a schema is to validate data. So rather than start with the schema, you first need to think about what the data should be. It's much easier to reason about data by just creating an example of it. We'll do that now by creating a _passing test document_ - i.e. a document representing data that will be validated by the schema we're creating.

### Define a passing test document <!-- omit in toc -->

Create a new file `all-properties.json` in the `pass` directory next to the schema we just created.

```bash
touch tutorial/finance/payments/payment-instruction/1/0/0/pass/all-properties.json
```

Here's an example of good data - copy it into the file.

```json
{
  "id": "12345678-1234-5678-1234-567812345678",
  "paymentDate": "2026-02-11T09:18:08Z",
  "amount": 100,
  "currency": "EUR"
}
```

> [!NOTE]
>
> In real life, reasoning about the right data structure can be a lengthy process. Later, we'll cover how complex data can be decomposed into simpler building blocks, some of which are reusable. Also, check out [Domain-Driven Design](geeksforgeeks.org/system-design/domain-driven-design-ddd/).

### Update the schema file <!-- omit in toc -->

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

- `$schema` is the version of the JSON Schema standard defined by the registry config file. (See `tutorial/json-schema-manager-config.yml`)
- `$id` in JSON Schema represents the canonical URL for the schema - I.e. the URL that services use to load the schema in an environment. **Always** leave it set to `{{ ID }}`. JSM will automatically replace it when it creates a distribution version for a target environment. (See `jsm build-dist` TODO LINK below).

Other than that, it's a standard JSON Schema.

> [!TIP]
>
> You can find out more about JSON Schema at [json-schema.org](https://json-schema.org/).

Ok, let's update this schema to validate our passing test document. Usually, you would ask AI to complete it given your passing document, then refine it, but for now, just use this example:

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

Like all source code, schemas must be tested for correctness. JSM makes this incredibly easy. Let's jump in.

### Running tests <!-- omit in toc -->

`jsm validate` is the command used to test one or more schemas in a registry. There are a lot of ways you can use it, but for now, just type:

```bash
jsm validate -v finance/payments/payment-instruction/1/0/0
```

> [!TIP]
>
> Type `jsm validate --help` to see all the options available for the `validate` command.

The `-v` flag (or `--verbose`) will show us which schemas were tested with which test documents. In our case, it tested `finance_payments_payment-instruction_1_0_0.schema.json` against `all-properties.json` and found that it passed.

### Adding a failing test <!-- omit in toc -->

It isn't enough to know that a schema validates the documents we expect. We also need to know that it rejects documents that shouldn't pass. That's the job of the `fail` directory.

Let's imagine that a payment-instruction cannot have a zero amount. So we'll create a test with that exact flaw. We'll first copy the passing test document...

```bash
cp tutorial/finance/payments/payment-instruction/1/0/0/pass/all-properties.json tutorial/finance/payments/payment-instruction/1/0/0/fail/amount-zero.json
```

..and then update the failing document (`tutorial/finance/payments/payment-instruction/1/0/0/fail/amount-zero.json`) so that the amount is zero:

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
jsm validate -v finance/payments/payment-instruction/1/0/0
```

The test using our failing test document reports `passed, when expected fail`. This is exactly what we want to see. Our failing test has exposed a flaw in our JSON Schema!

Let's take a look at the part of the schema defining the `amount` property:

```json
    "amount": {
      "type": "number"
    },
```

Currently, any number is admissable. This is wrong. Let's force it to be a non-zero positive number:

```json
    "amount": {
      "type": "number",
      "exclusiveMinimum": 0
    },
```

Once you've saved it, rerun the tests for this schema:

```bash
jsm validate -v finance/payments/payment-instruction/1/0/0
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

Imagine that we have already deployed our schema to production. This means we **must not** make any changes to that version. But now, the finance team want to add a new `status` property to support a feature.

Usually, it's possible to add new properties to a data document without breaking existing consumers of that data which are using an earlier schema for validation. In semantic versioning, this is an example of a **minor** change.

So we want create a new schema within our schema family. You can do this manually, but the best way is to use the `jsm create-schema-version` command. Let's do that now.

```bash
jsm create-schema-version finance/payments/payment-instruction minor
```

This did the following for you:

1. Worked out what the next version should be - `1.1.0` in this case.
2. Created the new directories
3. Worked out the **precursor** schema. This is the schema to use as a starting point for the changes you want to make in the new version
4. Copied the precursor schema to a new version directory, with the correct new filename.
5. Copied the pass and fail test documents from the precursor schema to the new version.

Cool! Now let's make some changes to the new version we just created. It's the same process as before...

### Define a passing test document <!-- omit in toc -->

The command we ran already copied `all-properties.json`. You'll find the new version in `tutorial/finance/payments/payment-instruction/1.1.0/pass/all-properties.json`.

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

### Run the tests <!-- omit in toc -->

Just like before, we can run the tests for this new schema version:

```bash
jsm validate -v finance/payments/payment-instruction/1/1/0
```

The tests passed, even though we added a new property to the passing test document. This isn't surprising, because the precursor schema didn't set `additionalProperties: false`, so it doesn't care if it sees a property it doesn't know about. This is a good thing, because it means if a consumer using an earlier version of our schema sees that data, it will still validate and not break the consumer.

### Update the schema to define the new status property <!-- omit in toc -->

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

### Run tests when a schema or test document changes <!-- omit in toc -->

To save us having to run the tests each time, we can use the `--watch` or `-w` flag to automatically run tests when a schema or test document changes:

```bash
jsm validate -w -v finance/payments
```

## 8. Composing schemas

The data that JSON Schema is used to validate is often highly structured and complex, especially in enterprise situations. Additionally, the same sub-structures are often used many times in different schemas. Simple examples might be addresses, or the specific format of a customer-facing ID, but for our schema example, let's imagine we want to capture the location of the device that generated the payment instruction.

### Creating a reusable schema

A common way to identify a location is using the [WGS-84](https://en.wikipedia.org/wiki/World_Geodetic_System) coordinate system. Let's create a schema for that.

We'll create a new schema family called `location`, and we'll put it in a place for reusable utility schemas.

```bash
jsm create-schema util/location/wgs-84
```

Let's define an example of a valid wgs-84 coordinate: Create a new passing test:

```bash
touch tutorial/util/location/wgs-84/1/0/0/pass/all-properties.json
```

Then edit it and set it to:

```json
{
  "latitude": 51.5074,
  "longitude": -0.1278
}
```

In the `fail` folder add some failing tests.

Now let's edit the schema - `tutorial/util/location/wgs-84/1/0/0/util_location_wgs-84_1_0_0.schema.json` - to define the properties:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "{{ ID }}",
  "title": "WGS-84 Location Schema",
  "description": "Schema for WGS-84 location validation",
  "type": "object",
  "properties": {
    "latitude": {
      "type": "number",
      "minimum": -90,
      "maximum": 90,
      "description": "Latitude in degrees"
    },
    "longitude": {
      "type": "number",
      "minimum": -180,
      "maximum": 180,
      "description": "Longitude in degrees"
    }
  },
  "required": ["latitude", "longitude"],
  "additionalProperties": false
}
```

Note that we used `additionalProperties: false`. In this case, we are certain that there will never be any additional future properties for this schema.

> [!WARNING]
>
> Only use `additionalProperties: false` when you are absolutely certain there will be no additional future properties for a schema.

Create some failing tests for this schema - e.g.:

```bash
touch tutorial/util/location/wgs-84/1/0/0/fail/latitude-too-high.json
touch tutorial/util/location/wgs-84/1/0/0/fail/latitude-too-low.json
touch tutorial/util/location/wgs-84/1/0/0/fail/longitude-too-high.json
touch tutorial/util/location/wgs-84/1/0/0/fail/longitude-too-low.json
touch tutorial/util/location/wgs-84/1/0/0/fail/missing-latitude.json
touch tutorial/util/location/wgs-84/1/0/0/fail/missing-longitude.json
touch tutorial/util/location/wgs-84/1/0/0/fail/latitude-not-a-number.json
touch tutorial/util/location/wgs-84/1/0/0/fail/longitude-not-a-number.json
touch tutorial/util/location/wgs-84/1/0/0/fail/extra-property.json
```

Edit each file and configure it to expose each failure case, and then run the tests, e.g.:

```bash
jsm validate -v util/location/wgs-84/1/0/0
```

### Using a reusable schema

Now that we have a reusable schema, we can use it in our payment instruction schema. We'll need to create a new minor version of the schema so we can add a new `location` property. Run the command we ran last time:

```bash
jsm create-schema-version finance/payments/payment-instruction minor
```

Oh no! It fails with:

```bash
Error: Schema target finance/payments/payment-instruction targets multiple schemas
```

This is because we now have multiple schema versions in the `finance/payments/payment-instruction` family - `1.0.0` and `1.1.0`. This command won't work if the command identifies multiple candidate precursor schemas.

So we can try again, but being more precise about the path to the precursor schema:

```bash
jsm create-schema-version finance/payments/payment-instruction/1/1/0 minor
```

Now it works:

```text
Successfully created new schema with key: finance_payments_payment-instruction_1_2_0

The schema and its test documents can be found here:
  <path/to>/tutorial/finance/payments/payment-instruction/1/2/0
```

The command copied the test documents from the precursor schema to the new schema version. We now need to add the `location` property to the passing test document. Edit:

```bash
tutorial/finance/payments/payment-instruction/1/2/0/pass/all-properties.json
```

And add the location property. Its value can just be the passing test document for the WGS-84 schema, e.g.:

```json
{
  "id": "12345678-1234-5678-1234-567812345678",
  "paymentDate": "2026-02-11T09:18:08Z",
  "amount": 100,
  "currency": "EUR",
  "status": "pending",
  "location": {
    "latitude": 51.5074,
    "longitude": -0.1278
  }
}
```

Before we continue, let's start watching for changes again:

```bash
jsm validate -w -v finance/payments
```

Now add the `location` property to the payment instruction schema. (`tutorial/finance/payments/payment-instruction/1/2/0/finance_payments_payment-instruction_1_2_0.schema.json`)

```json
    "location": {
      "type": "object",
      "$ref": "{{ JSM `util_location_wgs-84_1_0_0` }}"
    }

```

What's going on here? Let's break it down.

- `$ref`: This is a standard JSON Schema property that allows you to reference another schema.
- `{{ JSM <schema-key> }}`: This is a JSM template variable that will be replaced with the canonical ID of the JSM schema identified by `<schema-key>` - i.e. the URL of the schema once deployed in an environment.
- `util_location_wgs-84_1_0_0`: This is the JSM schema key for the WGS-84 location schema we created earlier.

> [!TIP]
>
> The **schema key** is also the **filename** of the target schema without the `.schema.json` suffix. This is not a coincidence - it's a convention that JSM uses to make it easier to find and reference schemas.

Save the schema. This will trigger another test run with the test document we just updated.

### Updating tests for new schema versions

The `create-schema-version` command automatically copied across passing and failing tests from the precursor schema, but often, you need to check and update the tests following your update of the schema itself, to make sure they are really testing what they say.

Currently, our new schema version (`finance_payments_payment-instruction_1_2_0.schema.json`) isn't requiring the `location` property to be present. Let's change that. Add `location` to the list of properties in the schema's `required` block as follows:

```json
  "required": [
    "id",
    "paymentDate",
    "amount",
    "currency",
    "status",
    "location"
  ]
```

When you save the schema, its tests run (and all pass), but the `fail/amount-zero.json` is unchanged from the previous schema version, i.e.:

```json
{
  "id": "12345678-1234-5678-1234-567812345678",
  "paymentDate": "2026-02-11T09:18:08Z",
  "amount": 0,
  "currency": "EUR"
}
```

There are now two problems with this test: - zero `amount` - missing `location`

First, let's add a location property to the `fail/amount-zero.json` document so there is just one error (zero `amount`):

```json
{
  "id": "12345678-1234-5678-1234-567812345678",
  "paymentDate": "2026-02-11T09:18:08Z",
  "amount": 0,
  "currency": "EUR",
  "status": "pending",
  "location": {
    "latitude": 51.5074,
    "longitude": -0.1278
  }
}
```

Now add an additional failing test - `fail/missing-location.json` which is correct except for the missing `location` property:

```json
{
  "id": "12345678-1234-5678-1234-567812345678",
  "paymentDate": "2026-02-11T09:18:08Z",
  "amount": 100,
  "currency": "EUR",
  "status": "pending"
}
```

> [!TIP]
>
> Always create a failing test document by copying a passing test document and introducing a single failure, matching the name of the failing test document.

### Testing references to other schemas

Our `util_location_wgs-84_1_0_0.schema.json` schema has a full suite of passing and failing test documents, so when we're using it in another schema, we **should not** replicate those tests in schemas which use it.

Instead, we just need to test for the presence of the location property, as we've already done.

> [!TIP]
>
> Always cleanly separate testing concerns between schemas. This is especially important when dealing with complex schemas which involve many nested references.
