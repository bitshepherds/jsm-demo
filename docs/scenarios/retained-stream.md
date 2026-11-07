# Retained streams: an order event log

Scenario `retained-stream`. [All scenarios](index.md) · [JSM's page on this scenario](https://github.com/bitshepherds/json-schema-manager/blob/v2.0.0/user-docs/scenarios.md#6-retained-streams)

A service publishes events to a log that keeps them for a set time, such as 30 days. A reader that lags behind the writer must accept new events, as with [owner writes](owner-writes.md). But a new reader, built against the newest version, may also replay the log from its oldest event, so it must accept old events too. So a change is checked in both directions, but only as far back as events may still be in the log.

## Who owns it, who follows, who moves first

- **Owner:** the order service, which publishes an `order-placed` event for each order, to a log kept for 30 days.
- **Followers:** the services reading the log. The fraud service may lag behind on an older version. A new analytics service, built against the newest version, replays the log from its oldest event.
- **Who moves first:** the owner.

## The worked example

The family is [`registry/order/placed/`](../../registry/order/placed/). Its [`family.yml`](../../registry/order/placed/family.yml) declares the scenario, and the oldest version whose events may still be in the log:

```yaml
scenario: retained-stream
# The oldest version whose events may still be in the log. Move it forward, in a reviewed change, once the last
# event written under it has expired.
oldestLive: 1.0.0
```

| Version | What it holds |
| --- | --- |
| `1.0.0` | An `orderId`, a `total`, and an optional `currency`. Its pass document is an event from before the shop sent one. |
| `1.1.0` | Describes `total` and `currency`, and nothing more. That is the safe change, and it is green. |

When a reader may be behind or ahead, few changes are safe in a minor version: nearly any change refuses something one side sends. Documenting a field is one that is. JSM proves it with all four runs across the two versions:

```sh
go tool jsm -r registry validate all -C
```

```text
[PASS] order_placed_1_1_0.schema.json (pass: 6, fail: 0)
```

## Break it

The shop wants every event to say which currency it is in. In `registry/order/placed/1/1/0/order_placed_1_1_0.schema.json`, make `currency` required:

```json
"required": ["orderId", "total", "currency"]
```

Validate:

```sh
go tool jsm -r registry validate all -C
```

It fails, with exit code 1:

```text
[FAIL] order_placed_1_1_0.schema.json (pass: 5, fail: 1)
  ✗ /path/to/jsm-demo/registry/order/placed/1/0/0/pass/no-currency.json (no-tightening broken: pass document of 1.0.0 rejected by 1.1.0):
    no-tightening broken between order_placed_1_0_0 and order_placed_1_1_0: pass document /path/to/jsm-demo/registry/order/placed/1/0/0/pass/no-currency.json of order_placed_1_0_0 was rejected by order_placed_1_1_0. In a retained-stream family, a reader on order_placed_1_1_0 rejects a document written under order_placed_1_0_0, which may still be around. Undo the change, or make it in a new major version. ...
- at '': missing property 'currency'
```

The fraud service is unaffected: every event it now gets has a currency. But the analytics service starts up, replays an event written three weeks ago under `1.0.0`, `{ "orderId": "ord-1001", "total": 25 }`, and refuses it. That is a **tightening**, and it breaks a reader that is ahead. A **loosening** breaks one that is behind, as with [owner writes](owner-writes.md), and JSM refuses that too.

### Let the old events expire

Keep the edit. Thirty days on, the last event written under `1.0.0` has left the log, so no reader can meet one. JSM uses no clock, so it can't know that: a person who knows it moves `oldestLive` forward, in a change someone reviews. In `registry/order/placed/family.yml`:

```yaml
oldestLive: 1.1.0
```

Validate again:

```sh
go tool jsm -r registry validate all -C
```

It passes, with exit code 0. `1.0.0` takes no part in the checks any more, so the same edit is now safe:

```text
[PASS] order_placed_1_1_0.schema.json (pass: 2, fail: 0)
```

Undo both edits:

```sh
git restore registry
```

The output above shortens the paths to `/path/to/jsm-demo`: JSM prints them in full ([bitshepherds/json-schema-manager#156](https://github.com/bitshepherds/json-schema-manager/issues/156)). The counts in brackets count runs, not documents ([#154](https://github.com/bitshepherds/json-schema-manager/issues/154)).

## What JSM checks, and what it leaves to you

JSM checks, within a major version, and from `oldestLive` on:

- **No loosening and no tightening.** All four runs across versions take place: later pass and earlier fail documents on the other version, and earlier pass and later fail documents on theirs.
- **Each version's own documents**, as in every scenario, including the versions below `oldestLive`.
- **A change that no document shows**, in either direction, with a warning.
- **That `oldestLive` names a version the family has**, so a typo can't quietly switch the checks off.

It leaves to you:

- **When to move `oldestLive`.** JSM doesn't know how long the log keeps events, or when the last old one was written. Moving it too soon lets a change through that a replaying reader still trips on.
- **Test documents that show each change**, in both directions.
