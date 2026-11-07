# A format someone else owns: a carrier's tracking webhook

Scenario `third-party-format`. [All scenarios](index.md) · [JSM's page on this scenario](https://github.com/bitshepherds/json-schema-manager/blob/v2.0.0/user-docs/scenarios.md#9-a-format-someone-else-owns)

Another organisation owns the format, and changes it when it chooses, perhaps without telling you. Your schema doesn't set the rules: it records what they send. So a new version records a change that has already happened, and it must still accept the older messages that keep arriving, and the samples you captured. When a check fails, it doesn't mean "you made a mistake, don't ship". It means "by this schema, the real format has changed, and here is how", so you can check it really has.

## Who owns it, who follows, who moves first

- **Owner:** a shipping carrier, another company, which decides what its tracking webhook sends.
- **Followers:** you. Your tracking service receives each webhook, and checks it against your schema.
- **Who moves first:** the carrier, and you can't ask it to wait.

## The worked example

The family is [`registry/carrier/tracking/`](../../registry/carrier/tracking/). Its [`family.yml`](../../registry/carrier/tracking/family.yml) declares the scenario, and how long webhooks live:

```yaml
scenario: third-party-format
# This scenario must say how long its documents live. Each webhook is read once, and gone.
documentsLive: moment
```

This scenario must state `documentsLive`: how long documents live varies, so the scenario alone is refused. A webhook read once and gone is `moment`. A file format whose files you keep would be `indefinitely`, and then a second major version would need a migration statement saying what happens to what you've kept. If you don't know, choose `indefinitely`.

| Version | What it holds |
| --- | --- |
| `1.0.0` | A `parcelId`, and a `status` from `label-created`, `in-transit`, `out-for-delivery` and `delivered`. Its pass document is a captured sample. |
| `1.1.0` | Adds `held-at-customs`, which the carrier started sending. That is the safe change, and it is green. |

The new status is recorded from a captured sample, `1.1.0`'s pass document. JSM doesn't run it on `1.0.0`: that `1.0.0` refuses it tells you only what you already know. It does run `1.0.0`'s samples on `1.1.0`, to be sure the old messages, still arriving, still pass:

```sh
go tool jsm -r registry validate all -C
```

```text
[PASS] carrier_tracking_1_1_0.schema.json (pass: 4, fail: 0)
```

## Break it

While drafting `1.1.0`, you rewrite the status list from this week's samples, which happen not to show `out-for-delivery`. In `registry/carrier/tracking/1/1/0/carrier_tracking_1_1_0.schema.json`, the list becomes:

```json
"status": { "enum": ["label-created", "in-transit", "held-at-customs", "delivered"] }
```

Validate:

```sh
go tool jsm -r registry validate all -C
```

It fails, with exit code 1, and says the real format has changed:

```text
[FAIL] carrier_tracking_1_1_0.schema.json (pass: 3, fail: 1)
  ✗ /path/to/jsm-demo/registry/carrier/tracking/1/0/0/pass/out-for-delivery.json (no-tightening broken: pass document of 1.0.0 rejected by 1.1.0):
    no-tightening broken between carrier_tracking_1_0_0 and carrier_tracking_1_1_0: pass document /path/to/jsm-demo/registry/carrier/tracking/1/0/0/pass/out-for-delivery.json of carrier_tracking_1_0_0 was rejected by carrier_tracking_1_1_0. In a third-party-format family, this says the real format has changed: carrier_tracking_1_1_0 rejects documents carrier_tracking_1_0_0 accepts. Its owner decides that, so check your readers cope with it. If the format hasn't really changed this way, correct carrier_tracking_1_1_0. ...
- at '/status': value must be one of 'label-created', 'in-transit', 'held-at-customs', 'delivered'
```

By your new schema, the carrier has stopped sending `out-for-delivery`. It hasn't: it still sends it for every parcel on its last leg, and your tracking service would refuse them all. A captured `1.0.0` sample that uses it showed this. That is a **tightening**: the same check as [owner reads](owner-reads.md), worded for a format you don't own.

Undo the edit:

```sh
git restore registry
```

The output above shortens the paths to `/path/to/jsm-demo`: JSM prints them in full ([bitshepherds/json-schema-manager#156](https://github.com/bitshepherds/json-schema-manager/issues/156)). The counts in brackets count runs, not documents ([#154](https://github.com/bitshepherds/json-schema-manager/issues/154)).

## What JSM checks, and what it leaves to you

JSM checks, within a major version:

- **No tightening.** Each earlier version's samples run on every later version, and each later version's fail documents run on every earlier version, and a failure says the real format has changed.
- **Each version's own documents**, as in every scenario.
- **That the family states `documentsLive`**, and, where documents are kept for good, a migration statement for each major past the first.

It leaves to you:

- **Whether the format really changed.** JSM can't ask the carrier. When a check fails, find out: correct your schema if you were wrong, or make sure your readers cope if the carrier really did change it.
- **Capturing samples.** Your test documents are real messages you have kept. The more kinds you keep, the more a careless rewrite is caught.
- **Major versions.** The carrier has already made its change, so choosing a major version changes nothing about the messages out there.
