# Stored data, each document names its version: issued invoices

Scenario `stored-self-naming`. [All scenarios](index.md) · [JSM's page on this scenario](https://github.com/bitshepherds/json-schema-manager/blob/v2.0.0/user-docs/scenarios.md#5-stored-data-each-document-names-its-version)

Each document says which version it was written under, and is only ever checked against that version: an archive of invoices, each stamped with its schema version. No version ever has to accept another version's documents, so the versions are free to differ. What matters is that each version describes its own documents correctly, and that no version is ever lost while documents still name it.

## Who owns it, who follows, who moves first

- **Owner:** the invoicing service, which decides what an invoice holds, and stamps each one with `schemaVersion` as it issues it.
- **Followers:** the audit tool, which reads each invoice's `schemaVersion`, and checks the invoice against that version.
- **Who moves first:** nobody needs to. Each invoice says which version it is, so the owner may change the schema whenever it likes.

## The worked example

The family is [`registry/billing/invoice/`](../../registry/billing/invoice/). Its [`family.yml`](../../registry/billing/invoice/family.yml) declares the scenario:

```yaml
scenario: stored-self-naming
```

| Version | What it holds |
| --- | --- |
| `1.0.0` | A `schemaVersion` that must be `"1.0.0"`, an `invoiceId` and a `total`. |
| `1.1.0` | A `schemaVersion` that must be `"1.1.0"`, and a `taxNumber`, which is **required**. That is the change, and it is green, though `1.0.0` invoices have none. |

In most scenarios, making a field required in a minor version is a break. Here it harms nothing: a 2022 invoice that names `1.0.0` is never checked against `1.1.0`. JSM runs **only each version's own documents**, with no runs across versions. Ask for the detail:

```sh
go tool jsm -r registry validate all -C --verbose
```

Under each version, every run is the version's own document. As elsewhere on this page, the paths are shortened to `/path/to/jsm-demo`:

```text
[PASS] billing_invoice_1_0_0.schema.json (pass: 2, fail: 0)
  ✓ /path/to/jsm-demo/registry/billing/invoice/1/0/0/pass/issued-2022.json (passed)
  ✓ /path/to/jsm-demo/registry/billing/invoice/1/0/0/fail/no-total.json (failed, as expected)
[PASS] billing_invoice_1_1_0.schema.json (pass: 2, fail: 0)
  ✓ /path/to/jsm-demo/registry/billing/invoice/1/1/0/pass/issued-2026.json (passed)
  ✓ /path/to/jsm-demo/registry/billing/invoice/1/1/0/fail/no-tax-number.json (failed, as expected)
```

## Break it

So the check that matters is each version against its own documents. Here is a mistake that check catches. `jsm create-schema-version` makes `1.1.0` by copying `1.0.0`'s schema, so it is easy to leave the old version number in it. In `registry/billing/invoice/1/1/0/billing_invoice_1_1_0.schema.json`, put the old number back:

```json
"schemaVersion": { "const": "1.0.0" },
```

Validate:

```sh
go tool jsm -r registry validate all -C
```

It fails, with exit code 1:

```text
[FAIL] billing_invoice_1_1_0.schema.json (pass: 1, fail: 1)
  ✗ /path/to/jsm-demo/registry/billing/invoice/1/1/0/pass/issued-2026.json (failed):
    Pass Test document /path/to/jsm-demo/registry/billing/invoice/1/1/0/pass/issued-2026.json did not pass validation as expected for schema /path/to/jsm-demo/registry/billing/invoice/1/1/0/billing_invoice_1_1_0.schema.json, error: jsonschema validation failed with 'https://json-schemas.internal.example.com/billing_invoice_1_1_0.schema.json#'
- at '/schemaVersion': value must be '1.0.0'
```

`1.1.0` now refuses every invoice issued under it, starting with its own pass document. No rule across versions broke: the version doesn't describe its own documents. Without that pass document, the audit tool would have found it, on the first invoice it read.

Undo the edit:

```sh
git restore registry
```

The output above shortens the paths to `/path/to/jsm-demo`: JSM prints them in full ([bitshepherds/json-schema-manager#156](https://github.com/bitshepherds/json-schema-manager/issues/156)). The counts in brackets count runs, not documents ([#154](https://github.com/bitshepherds/json-schema-manager/issues/154)).

## What JSM checks, and what it leaves to you

JSM checks:

- **Each version's own documents**, and nothing across versions, since these versions never need to agree.
- **That no deployed version is deleted.** A document may name it for years, so once a version is deployed, `jsm check-changes` refuses deleting it.

A new major version needs no migration statement, since old documents go on naming their old version.

It leaves to you:

- **Making the version field required, in every version.** JSM can't know which property holds the version. If a document may leave it out, the reader has to guess, and the family should be [stored data, one schema for all](stored-one-schema.md) instead.
- **Reading each version.** The reader must handle every version a document may name, or migrate it. That is your code.
- **A pass and a fail document for every version.** Nothing is inherited from an earlier version, since nothing runs across versions.
