# Owner writes: an API's response

Scenario `owner-writes`. [All scenarios](index.md) · [JSM's page on this scenario](https://github.com/bitshepherds/json-schema-manager/blob/v2.0.0/user-docs/scenarios.md#1-owner-writes)

The owner of the contract writes the documents, and everyone else reads them: an API's response, an event a service publishes, a tool's JSON output. The owner changes first, and its readers catch up later. So the danger is a reader that is behind: a new version must never send something an older reader would refuse.

## Who owns it, who follows, who moves first

- **Owner:** the order service, which decides what its create-order response holds.
- **Followers:** the shop's clients, which read the response with code built against the version they were built with.
- **Who moves first:** the owner. It deploys `1.1.0` and sends `1.1.0` responses at once, while some clients are still on `1.0.0`.

## The worked example

The family is [`registry/order/response/`](../../registry/order/response/), the same one the [getting-started walk-through](../getting-started.md) uses. Its [`family.yml`](../../registry/order/response/family.yml) declares the scenario:

```yaml
scenario: owner-writes
```

| Version | What it holds                                                          |
| ------- | ---------------------------------------------------------------------- |
| `1.0.0` | `orderId`, and a `status` of `placed` or `shipped`.                    |
| `1.1.0` | Adds an optional `currency`. That is the safe change, and it is green. |

Adding a field the service sends harms no client: `1.0.0` is open, so a `1.0.0` client accepts a response with a `currency` it doesn't know. JSM proves it by running `1.1.0`'s pass document on `1.0.0`:

```sh
go tool jsm -r registry validate all -C
```

```text
[PASS] order_response_1_1_0.schema.json (pass: 3, fail: 0)
```

## Break it

The service wants to send any status it likes in future. In `registry/order/response/1/1/0/order_response_1_1_0.schema.json`, replace the list of statuses with any string:

```json
"status": { "type": "string" }
```

Validate:

```sh
go tool jsm -r registry validate all -C
```

It fails, with exit code 1:

```text
[FAIL] order_response_1_1_0.schema.json (pass: 2, fail: 1)
  ✗ /path/to/jsm-demo/registry/order/response/1/0/0/fail/unknown-status.json (no-loosening broken: fail document of 1.0.0 accepted by 1.1.0):
    no-loosening broken between order_response_1_0_0 and order_response_1_1_0: fail document /path/to/jsm-demo/registry/order/response/1/0/0/fail/unknown-status.json of order_response_1_0_0 was accepted by order_response_1_1_0. In a owner-writes family, a writer on order_response_1_1_0 can send a reader still on order_response_1_0_0 a document it rejects. Undo the change, or make it in a new major version. ...
```

`1.0.0`'s fail document, `{ "orderId": "ord-1001", "status": "not-a-status" }`, is a response a `1.0.0` client refuses. `1.1.0` now lets the service send it. That is a **loosening**, and a client still on `1.0.0` would reject the first such response it got. JSM didn't need a new document to find this: it ran the earlier version's fail document on the later version.

Undo the edit:

```sh
git restore registry
```

The output above shortens the paths to `/path/to/jsm-demo`: JSM prints them in full ([bitshepherds/json-schema-manager#156](https://github.com/bitshepherds/json-schema-manager/issues/156)). "a owner-writes" will read "an owner-writes" ([#153](https://github.com/bitshepherds/json-schema-manager/issues/153)), and the counts in brackets count runs, not documents ([#154](https://github.com/bitshepherds/json-schema-manager/issues/154)).

## What JSM checks, and what it leaves to you

JSM checks, within a major version:

- **No loosening.** Each later version's pass documents run on every earlier version, and each earlier version's fail documents run on every later version. A later version may not accept what an earlier one rejects.
- **Each version's own documents**, as in every scenario.
- **A widening that no document shows.** If a later version accepts more and no pass document uses it, such as a new status, `validate` warns. The walk-through's [step 7](../getting-started.md#step-7-a-subtler-case-a-new-status) shows one.

It leaves to you:

- **Keeping the schema open.** If `1.0.0` had `"additionalProperties": false`, no field could ever be added in a minor version.
- **Tightening.** A later version may reject more, such as making a field required, since the service then always sends it. JSM allows it, and doesn't check it.
- **Test documents that show each change.** The checks are only as strong as the documents.
- **A change the scenario forbids** is made in a new major version, which clients move to before the service stops sending the old one. See the walk-through's [step 5](../getting-started.md#step-5-the-fix-a-new-major-version).
