# Lock-step: a file passed between two steps of one job

Scenario `lock-step`. [All scenarios](index.md) · [JSM's page on this scenario](https://github.com/bitshepherds/json-schema-manager/blob/v2.0.0/user-docs/scenarios.md#8-lock-step)

One team owns both the writer and the reader, and always releases them together, and no document outlives the release. A reader can never meet a document from another version, so versions needn't agree with each other at all. What matters is that each version describes its own documents correctly.

## Who owns it, who follows, who moves first

- **Owner:** the team that owns a batch job, and both of its steps.
- **Followers:** none apart: both steps are the owner's.
- **Who moves first:** both sides together. The planner step writes `plan.json`, the executor step reads it and throws it away, and both ship in one container image, so they are always on the same version.

## The worked example

The family is [`registry/batch/plan/`](../../registry/batch/plan/). Its [`family.yml`](../../registry/batch/plan/family.yml) declares the scenario:

```yaml
scenario: lock-step
```

| Version | What it holds |
| --- | --- |
| `1.0.0` | A `jobId`, and a list of `steps`. |
| `1.1.0` | Renames `steps` to `tasks`. That is the change, and it is green, though a `1.0.0` plan would fail on `1.1.0`. |

In any other scenario, a rename in a minor version breaks someone. Here it harms nobody: no executor on `1.0.0` can ever read a `1.1.0` plan. JSM runs **only each version's own documents**, with no runs across versions:

```sh
go tool jsm -r registry validate all -C
```

```text
[PASS] batch_plan_1_0_0.schema.json (pass: 2, fail: 0)
[PASS] batch_plan_1_1_0.schema.json (pass: 2, fail: 0)
```

Each version's two runs are its own pass document, accepted, and its own fail document, rejected. Add `--verbose` to see each run.

## Break it

So the check that matters is each version against its own documents. Here is a mistake it catches: a typo in the rename. In `registry/batch/plan/1/1/0/batch_plan_1_1_0.schema.json`, misspell the required field:

```json
"required": ["jobId", "taks"]
```

Validate:

```sh
go tool jsm -r registry validate all -C
```

It fails, with exit code 1:

```text
[FAIL] batch_plan_1_1_0.schema.json (pass: 1, fail: 1)
  ✗ /path/to/jsm-demo/registry/batch/plan/1/1/0/pass/nightly.json (failed):
    Pass Test document /path/to/jsm-demo/registry/batch/plan/1/1/0/pass/nightly.json did not pass validation as expected for schema /path/to/jsm-demo/registry/batch/plan/1/1/0/batch_plan_1_1_0.schema.json, error: jsonschema validation failed with 'https://json-schemas.internal.example.com/batch_plan_1_1_0.schema.json#'
- at '': missing property 'taks'
```

`1.1.0` now refuses every real plan, starting with its own pass document, `{ "jobId": "nightly", "tasks": ["extract", "load"] }`. No rule across versions broke. Without that pass document, the job would have failed in production on its first run.

Undo the edit:

```sh
git restore registry
```

The output above shortens the paths to `/path/to/jsm-demo`: JSM prints them in full ([bitshepherds/json-schema-manager#156](https://github.com/bitshepherds/json-schema-manager/issues/156)). The counts in brackets count runs, not documents ([#154](https://github.com/bitshepherds/json-schema-manager/issues/154)).

## What JSM checks, and what it leaves to you

JSM checks:

- **Each version's own documents**, and nothing across versions, since a reader never meets another version's documents.

It leaves to you:

- **That the two sides really ship together.** If the planner and the executor ever deploy apart, or a plan is kept and read by a later release, this is the wrong scenario, and changes that break the other side go unchecked. Choose [owner writes](owner-writes.md), or [uncoordinated](uncoordinated.md), instead.
- **A pass and a fail document for every version.** Nothing is inherited from an earlier version, since nothing runs across versions.
