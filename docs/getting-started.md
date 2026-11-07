# Getting started: break and fix an API contract

An online shop has an API to create an order. The client sends a **request** body, and the order service sends back a **response** body. Each body has its own schema in this repo's registry, and each is a contract: change it the wrong way, and something in production starts rejecting orders.

In about fifteen minutes, you will make the same one-line change to both schemas. JSM, the JSON Schema Manager, passes it on one and refuses it on the other, and says why. You will then fix the broken one in the two proper ways, and see a second, subtler case.

Every step on this page is replayed automatically, on every change to this repo, by [`scripts/replay-getting-started.sh`](../scripts/replay-getting-started.sh). If JSM stops doing what this page says, the build fails.

## Contents <!-- omit in toc -->

- [Before you start](#before-you-start)
- [The example: an order API](#the-example-an-order-api)
- [Step 1: make currency required in the response](#step-1-make-currency-required-in-the-response)
- [Step 2: make the same change to the request](#step-2-make-the-same-change-to-the-request)
- [Step 3: see the change as JSM sees it](#step-3-see-the-change-as-jsm-sees-it)
- [Step 4: ask who it harms](#step-4-ask-who-it-harms)
- [Step 5: the fix, a new major version](#step-5-the-fix-a-new-major-version)
- [Step 6: an aside, a deliberate exception](#step-6-an-aside-a-deliberate-exception)
- [Step 7: a subtler case, a new status](#step-7-a-subtler-case-a-new-status)
- [What you have seen](#what-you-have-seen)

## Before you start

You need [Go](https://go.dev/dl/) 1.27.3 or later, and a clone of this repo. Run every command from the repo's root folder. JSM is pinned in `go.mod`, so `go tool jsm` fetches and runs the right version the first time you use it.

Every command passes `-r registry`, which tells JSM where the registry is. Do the same in your own work: until [bitshepherds/json-schema-manager#158](https://github.com/bitshepherds/json-schema-manager/issues/158) is fixed, an exported `JSM_REGISTRY_ROOT_DIR` overrides the current folder, so either unset it or always pass `-r`. Every `validate` passes `-C` too, which keeps it going after the first failure, so that you see every result.

Check that the registry starts green:

```sh
go tool jsm -r registry validate all -C
```

Each step edits the registry by hand. To get back to green at any time, run:

```sh
git restore registry && git clean -fd registry
```

`git restore` undoes your edits, and `git clean` removes the files you added. Both touch only `registry/`.

## The example: an order API

The registry holds two families, each with versions `1.0.0` and `1.1.0`:

| Family           | What it is                                 | Who owns it                        | Its scenario   |
| ---------------- | ------------------------------------------ | ---------------------------------- | -------------- |
| `order/request`  | The body a client sends to create an order | The order service, which reads it  | `owner-reads`  |
| `order/response` | The body the order service sends back      | The order service, which writes it | `owner-writes` |

Each family declares its scenario in its `family.yml`. The scenario says how the documents are used, and that decides which changes are safe. Version `1.1.0` of each adds an optional `currency` field.

Each version has test documents beside its schema: `pass/` holds documents it must accept, and `fail/` holds documents it must reject. JSM runs each version's own documents, and then, depending on the scenario, runs documents from one version on its neighbours in the same major version. That is how it finds a change that breaks someone.

## Step 1: make currency required in the response

The shop decides every response should say which currency the order is in. In `registry/order/response/1/1/0/order_response_1_1_0.schema.json`, add `currency` to the required fields:

```json
"required": ["orderId", "status", "currency"]
```

Validate:

```sh
go tool jsm -r registry validate all -C
```

It passes, with exit code 0:

```text
[PASS] order_response_1_1_0.schema.json (pass: 3, fail: 0)
```

That is right. The order service writes responses, and its clients read them. A client still on `1.0.0` reads a response with a `currency` field happily, since `1.0.0` allows extra fields. Requiring the field means the service always sends it: no client can be harmed.

But did JSM check anything, or did nothing run? Ask for the detail:

```sh
go tool jsm -r registry validate all -C --verbose
```

Under `order_response_1_1_0`, it shows the runs across versions:

```text
no-loosening holds: pass document of 1.1.0 accepted by 1.0.0
no-loosening holds: fail document of 1.0.0 rejected by 1.1.0
```

In an `owner-writes` family, the reader may be behind the writer, so a later version must not **loosen**: it must not let the writer send anything an earlier reader rejects. JSM ran `1.1.0`'s pass document on `1.0.0` to prove a `1.0.0` client accepts what `1.1.0` sends. The check ran, and held.

## Step 2: make the same change to the request

Now make the identical edit to the request. In `registry/order/request/1/1/0/order_request_1_1_0.schema.json`:

```json
"required": ["productId", "quantity", "currency"]
```

Leave the response edit in place, and validate again:

```sh
go tool jsm -r registry validate all -C
```

This time it fails, with exit code 1:

```text
[FAIL] order_request_1_1_0.schema.json (pass: 1, fail: 1)
  ✗ /path/to/jsm-demo/registry/order/request/1/0/0/pass/two-widgets.json (no-tightening broken: pass document of 1.0.0 rejected by 1.1.0):
    no-tightening broken between order_request_1_0_0 and order_request_1_1_0: pass document /path/to/jsm-demo/registry/order/request/1/0/0/pass/two-widgets.json of order_request_1_0_0 was rejected by order_request_1_1_0. In a owner-reads family, a reader on order_request_1_1_0 rejects a document a writer still on order_request_1_0_0 can send. Undo the change, or make it in a new major version. If this is deliberate, or order_request_1_1_0 is already deployed, list it in compat-exceptions.yml in order_request_1_1_0's directory. Detail: ...
- at '': missing property 'currency'
```

The order service reads requests, and moves to `1.1.0` first. Its clients write them, and move when they can. A client still on `1.0.0` sends `{ "productId": "widget", "quantity": 2 }`, which was a perfectly good order, and the service now rejects it. In an `owner-reads` family, a later version must not **tighten**: it must not reject anything an earlier writer can send. JSM found it with a document that was already there: `1.0.0`'s own pass document, run on `1.1.0`. You didn't need to write a new one.

The same one-line edit is safe on one side of the API and breaks callers on the other.

Some of this output will read better in a later JSM release:

- "a owner-reads" will read "an owner-reads" ([bitshepherds/json-schema-manager#153](https://github.com/bitshepherds/json-schema-manager/issues/153)).
- `(pass: 1, fail: 1)` counts runs, not documents ([bitshepherds/json-schema-manager#154](https://github.com/bitshepherds/json-schema-manager/issues/154)).
- The paths are absolute, and long ([bitshepherds/json-schema-manager#156](https://github.com/bitshepherds/json-schema-manager/issues/156)); this page shortens them to `/path/to/jsm-demo`.
- After the failure, the report also warns that `/: required requires "currency" (narrows): needs a fail document`, which repeats what the failure already showed ([bitshepherds/json-schema-manager#157](https://github.com/bitshepherds/json-schema-manager/issues/157)).

## Step 3: see the change as JSM sees it

`jsm diff` lists every structural change between two versions, whatever the scenario. Keep both edits, and compare each family's two versions:

```sh
go tool jsm -r registry diff order_response_1_0_0 order_response_1_1_0
go tool jsm -r registry diff order_request_1_0_0 order_request_1_1_0
```

Both list the same change:

```text
narrows  /: required requires "currency"
```

Each edit **narrows** what the schema accepts: `1.1.0` now rejects a document without `currency` that `1.0.0` accepted. `diff` doesn't judge. It is the family's scenario that decides whether narrowing matters: it is harmless where the owner writes, and it breaks callers where the owner reads.

## Step 4: ask who it harms

A party is a service or tool that reads or writes a family's documents. Its manifest lists its role and the versions it uses, and `jsm check-party` tells it whether a later version can harm it. This repo keeps two manifests in [`getting-started/parties/`](../getting-started/parties/): `writer.yml`, for a client that sends requests on `1.0.0`, and `reader.yml`, for the order service, on `1.0.0` too.

With the request edit still in place, check the writer:

```sh
go tool jsm -r registry check-party getting-started/parties/writer.yml
```

It fails, with exit code 1, just as `validate` did, and for the same reason:

```text
[FAIL] order_request_1_0_0 (1 document run)
  ✗ order_request_1_1_0: /path/to/jsm-demo/registry/order/request/1/0/0/pass/two-widgets.json (no-tightening broken: pass document of 1.0.0 rejected by 1.1.0):
```

Now the reader:

```sh
go tool jsm -r registry check-party getting-started/parties/reader.yml
```

It passes, with exit code 0, and a notice:

```text
[NOTICE] order_request_1_0_0
  i This family is declared owner-reads: the owner reads the documents, and moves to a new version before its followers, who write them, so no later version can harm a reader on order_request_1_0_0.
```

Run `check-party` in each party's own build, and a team learns that a change harms it before the change ships, not after.

## Step 5: the fix, a new major version

The request change can't be made in `1.x`. The proper way to make it is a new major version: a new flow, run side by side with the old one. Clients move to `2.0.0` when they can, and the order service stops accepting `1.x` once they have. No test document crosses a major version, so `2.0.0` is free to require `currency`.

First, put `1.1.0` back as it was, keeping `currency` optional there:

```sh
git restore registry && git clean -fd registry
```

Then create the next major version from `1.1.0`:

```sh
go tool jsm -r registry create-schema-version order_request_1_1_0 major
```

```text
Successfully created new schema with key: order_request_2_0_0
```

JSM copies `1.1.0`'s schema and its own test documents into `registry/order/request/2/0/0/`. Now make the change there:

1. In `order_request_2_0_0.schema.json`, make `currency` required: `"required": ["productId", "quantity", "currency"]`.
2. The copied pass document, `pass/with-currency.json`, already has a `currency`, so keep it as it is.
3. Add a fail document, `fail/no-currency.json`, to prove `2.0.0` rejects a request without one:

   ```json
   { "productId": "widget", "quantity": 2 }
   ```

Validate:

```sh
go tool jsm -r registry validate all -C
```

It passes, with exit code 0:

```text
[PASS] order_request_2_0_0.schema.json (pass: 2, fail: 0)
```

If you'd rather not edit by hand, copy the ready-made fix over the registry instead. It also puts `1.1.0` back as it was:

```sh
cp -R getting-started/fixes/major-bump/. registry/
```

An `owner-reads` or `owner-writes` family needs no migration statement for a new major version: its documents are read and gone in moments, so there are none left to move. A family whose documents stay around, such as a settings file, needs one in its `family.yml`. See the [config files scenario](https://github.com/bitshepherds/json-schema-manager/blob/v2.0.0/user-docs/scenarios.md#3-config-files).

Now check the writer still on `1.0.0`:

```sh
go tool jsm -r registry check-party getting-started/parties/writer.yml
```

It passes, with exit code 0, and warns the client to move:

```text
[WARN] order_request_1_0_0 (1 document run)
  ! the family has a newer major version, order_request_2_0_0, which this check doesn't cover: move to it before readers stop accepting version 1
```

## Step 6: an aside, a deliberate exception

Sometimes a break is the right call. Perhaps every client already sends `currency`, and you know it. JSM lets you say so, with a reason, in the later version's `compat-exceptions.yml`.

Go back to green:

```sh
git restore registry && git clean -fd registry
```

Make the request edit from [step 2](#step-2-make-the-same-change-to-the-request) again, so that `1.1.0` requires `currency`. Then create `registry/order/request/1/1/0/compat-exceptions.yml`:

```yaml
exceptions:
  - version: 1.0.0
    document: pass/two-widgets.json
    rule: no-tightening
    reason: Every client already sends currency, as the order service has asked since 1.1.0 shipped.
```

Or copy the ready-made one in:

```sh
cp -R getting-started/fixes/exception/. registry/
```

Validate:

```sh
go tool jsm -r registry validate all -C
```

It passes, with exit code 0, and the report keeps the break, and its reason, in plain sight:

```text
[PASS] order_request_1_1_0.schema.json (pass: 1, fail: 0, excepted: 1)
  ~ /path/to/jsm-demo/registry/order/request/1/0/0/pass/two-widgets.json (no-tightening excepted: pass document of 1.0.0 rejected by 1.1.0):
    reason: Every client already sends currency, as the order service has asked since 1.1.0 shipped.
```

An entry clears that one run and nothing else, and an entry that clears nothing fails, so they don't pile up. The report still warns that `/: required requires "currency" (narrows): needs a fail document`, so `validate --strict`, which fails on warnings, would fail here. That warning goes once [bitshepherds/json-schema-manager#157](https://github.com/bitshepherds/json-schema-manager/issues/157) is fixed. Use an exception sparingly: a new major version is the fix that harms no one.

## Step 7: a subtler case, a new status

Go back to green:

```sh
git restore registry && git clean -fd registry
```

The shop starts refunding orders, so the response's `status` gains a value. In `registry/order/response/1/1/0/order_response_1_1_0.schema.json`, add `refunded`:

```json
"status": { "enum": ["placed", "shipped", "refunded"] }
```

Validate:

```sh
go tool jsm -r registry validate all -C
```

It passes, with exit code 0, but warns:

```text
[WARN] order_response_1_1_0.schema.json since order_response_1_0_0:
  ! /status: enum adds "refunded" (widens): needs a pass document
```

No document uses `refunded`, so no check can tell whether it harms anyone. JSM's checks are only as strong as the test documents, so it points out a change in the direction the scenario protects that no document shows. Do what it asks, and add `registry/order/response/1/1/0/pass/refunded.json`:

```json
{ "orderId": "ord-1001", "status": "refunded", "currency": "GBP" }
```

Validate again, and it fails, with exit code 1:

```text
[FAIL] order_response_1_1_0.schema.json (pass: 4, fail: 1)
  ✗ /path/to/jsm-demo/registry/order/response/1/1/0/pass/refunded.json (no-loosening broken: pass document of 1.1.0 rejected by 1.0.0):
```

A client still on `1.0.0` knows only `placed` and `shipped`, and rejects a response that says `refunded`. Adding a value to a list the service sends is a break, though it looked like an addition. The warning led to the document, and the document proved the break. The fix is the same as in [step 5](#step-5-the-fix-a-new-major-version): a new major version of the response.

Go back to green:

```sh
git restore registry && git clean -fd registry
go tool jsm -r registry validate all -C
```

```text
Test summary: 9 passed, 0 failed
```

## What you have seen

- **How a schema is used decides which changes are safe.** The same edit passed on the response, which the owner writes, and failed on the request, which the owner reads.
- **JSM proves it with test documents**, run across versions in the direction the scenario protects. `validate --verbose` shows each run.
- **`jsm diff`** lists every change and which way it goes. **`jsm check-party`** tells each reader and writer whether a later version can harm it.
- **A new major version** is how to make a change the scenario forbids. **`compat-exceptions.yml`** records a deliberate break, with its reason.
- **A warning about an unexercised change** means no document shows it yet. Add one, and the check says whether it breaks anyone.
