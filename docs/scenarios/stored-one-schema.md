# Stored data, one schema for all: customer records

Scenario `stored-one-schema`. [All scenarios](index.md) · [JSM's page on this scenario](https://github.com/bitshepherds/json-schema-manager/blob/v2.0.0/user-docs/scenarios.md#4-stored-data-one-schema-for-all)

A service saves records, and reads them back, for years. The records don't say which version they were saved under, so the service checks every one, however old, against its newest schema. So a new version must accept every record any earlier version accepted: a record saved in 2019 is still in the database, and its customer still needs to log in.

## Who owns it, who follows, who moves first

- **Owner:** the accounts service, which saves customer profiles and decides what they hold.
- **Followers:** its own later releases, which read the profiles earlier releases saved. Here the owner is its own follower, and what lags behind is the data.
- **Who moves first:** the owner, against its own past: each new release must still read what every old release saved.

## The worked example

The family is [`registry/customer/profile/`](../../registry/customer/profile/). Its [`family.yml`](../../registry/customer/profile/family.yml) declares the scenario:

```yaml
scenario: stored-one-schema
```

| Version | What it holds |
| --- | --- |
| `1.0.0` | A `customerId`, a `name`, and an optional `email`. It is closed. Its pass document is a 2019 profile with no email address. |
| `1.1.0` | Adds an optional `preferredLanguage`. That is the safe change, and it is green. |

Adding an optional field harms no saved profile: the old ones don't have it, and needn't. JSM proves it by running `1.0.0`'s pass document on `1.1.0`:

```sh
go tool jsm -r registry validate all -C
```

```text
[PASS] customer_profile_1_1_0.schema.json (pass: 4, fail: 0)
```

## Break it

The business now wants an email address for every customer. In `registry/customer/profile/1/1/0/customer_profile_1_1_0.schema.json`, make `email` required:

```json
"required": ["customerId", "name", "email"]
```

Validate:

```sh
go tool jsm -r registry validate all -C
```

It fails, with exit code 1:

```text
[FAIL] customer_profile_1_1_0.schema.json (pass: 3, fail: 1)
  ✗ /path/to/jsm-demo/registry/customer/profile/1/0/0/pass/signed-up-without-email.json (no-tightening broken: pass document of 1.0.0 rejected by 1.1.0):
    no-tightening broken between customer_profile_1_0_0 and customer_profile_1_1_0: pass document /path/to/jsm-demo/registry/customer/profile/1/0/0/pass/signed-up-without-email.json of customer_profile_1_0_0 was rejected by customer_profile_1_1_0. In a stored-one-schema family, a reader on customer_profile_1_1_0 rejects a document written under customer_profile_1_0_0, which may still be around. Undo the change, or make it in a new major version. ...
- at '': missing property 'email'
```

The customer who signed up in 2019, before the service asked for an email address, has the profile `{ "customerId": "cus-2019-0042", "name": "Ada Lovelace" }`. The new release refuses it as it loads, and they can't log in. That is a **tightening**.

A new major version doesn't solve this on its own, as it would for an API: the 2019 profile is still in the database. So a major version past the first needs a migration statement in `family.yml`, saying how old records move, just as the [config-file](config-file.md#break-it-another-way-leave-out-the-migration-statement) example shows.

Undo the edit:

```sh
git restore registry
```

The output above shortens the paths to `/path/to/jsm-demo`: JSM prints them in full ([bitshepherds/json-schema-manager#156](https://github.com/bitshepherds/json-schema-manager/issues/156)). The counts in brackets count runs, not documents ([#154](https://github.com/bitshepherds/json-schema-manager/issues/154)).

## What JSM checks, and what it leaves to you

JSM checks, within a major version:

- **No tightening.** Each earlier version's pass documents run on every later version, and each later version's fail documents run on every earlier version. A later version may not refuse a record an earlier one accepted.
- **Each version's own documents**, as in every scenario.
- **A migration statement for each major past the first**, in `family.yml`.

It leaves to you:

- **The data.** JSM tests your test documents, not your database. A real record that no test document resembles can still be refused. Keep a pass document for each shape of record you have saved.
- **The migration.** The statement says how old records move to a new major. The code that moves them is yours.
