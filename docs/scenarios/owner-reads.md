# Owner reads: an API's request

Scenario `owner-reads`. [All scenarios](index.md) · [JSM's page on this scenario](https://github.com/bitshepherds/json-schema-manager/blob/v2.0.0/user-docs/scenarios.md#2-owner-reads)

The owner of the contract reads the documents, and everyone else writes them: an API's request body, or partners submitting files to one service. The owner changes first, and its writers catch up later. So the danger is a writer that is behind: a new version must never refuse something an older writer still sends.

## Who owns it, who follows, who moves first

- **Owner:** the order service, which decides what a create-order request holds, and reads every one.
- **Followers:** the shop's clients, which write requests with code built against the version they were built with.
- **Who moves first:** the owner. It deploys `1.1.0` before any client uses it, and goes on receiving `1.0.0` requests from clients that haven't moved.

## The worked example

The family is [`registry/order/request/`](../../registry/order/request/), the same one the [getting-started walk-through](../getting-started.md) uses. Its [`family.yml`](../../registry/order/request/family.yml) declares the scenario:

```yaml
scenario: owner-reads
```

| Version | What it holds                                                                                    |
| ------- | ------------------------------------------------------------------------------------------------ |
| `1.0.0` | `productId`, and a `quantity` of at least 1. It is closed: it rejects any field it doesn't list. |
| `1.1.0` | Adds an optional `currency`. That is the safe change, and it is green.                           |

The service accepting a new, optional field harms no client: a client that doesn't send it is unaffected, and the service is ready for those that do. JSM proves it by running `1.0.0`'s pass document on `1.1.0`:

```sh
go tool jsm -r registry validate all -C
```

```text
[PASS] order_request_1_1_0.schema.json (pass: 2, fail: 0)
```

## Break it

This is step 2 of the walk-through, in short. In `registry/order/request/1/1/0/order_request_1_1_0.schema.json`, make `currency` required:

```json
"required": ["productId", "quantity", "currency"]
```

Validate:

```sh
go tool jsm -r registry validate all -C
```

It fails, with exit code 1:

```text
[FAIL] order_request_1_1_0.schema.json (pass: 1, fail: 1)
  ✗ /path/to/jsm-demo/registry/order/request/1/0/0/pass/two-widgets.json (no-tightening broken: pass document of 1.0.0 rejected by 1.1.0):
    no-tightening broken between order_request_1_0_0 and order_request_1_1_0: pass document /path/to/jsm-demo/registry/order/request/1/0/0/pass/two-widgets.json of order_request_1_0_0 was rejected by order_request_1_1_0. In a owner-reads family, a reader on order_request_1_1_0 rejects a document a writer still on order_request_1_0_0 can send. Undo the change, or make it in a new major version. ...
- at '': missing property 'currency'
```

A client still on `1.0.0` sends `{ "productId": "widget", "quantity": 2 }`, a good order yesterday, and the service now refuses it. That is a **tightening**. The same edit on the response is safe: see [owner writes](owner-writes.md), and the walk-through's [step 1](../getting-started.md#step-1-make-currency-required-in-the-response).

Undo the edit:

```sh
git restore registry
```

The output above shortens the paths to `/path/to/jsm-demo`: JSM prints them in full ([bitshepherds/json-schema-manager#156](https://github.com/bitshepherds/json-schema-manager/issues/156)). "a owner-reads" will read "an owner-reads" ([#153](https://github.com/bitshepherds/json-schema-manager/issues/153)), and the counts in brackets count runs, not documents ([#154](https://github.com/bitshepherds/json-schema-manager/issues/154)).

## What JSM checks, and what it leaves to you

JSM checks, within a major version:

- **No tightening.** Each earlier version's pass documents run on every later version, and each later version's fail documents run on every earlier version. A later version may not reject what an earlier one accepts.
- **Each version's own documents**, as in every scenario.
- **A narrowing that no document shows.** If a later version rejects more and no fail document shows it, `validate` warns.

It leaves to you:

- **Loosening.** A later version may accept more, such as a new optional field or a new enum value. Clients that don't use it are unaffected, so JSM allows it.
- **Test documents that show each change.** The checks are only as strong as the documents.
- **A change the scenario forbids** is made in a new major version, which clients move to before the service stops accepting the old one. The walk-through's [step 5](../getting-started.md#step-5-the-fix-a-new-major-version) makes one, and [step 4](../getting-started.md#step-4-ask-who-it-harms) shows `check-party` telling each client whether a change harms it.
