# Deployed versions are frozen

Once a version of a schema is live, other systems rely on it exactly as it is. A client was built against it, a settings file was written to it, an invoice names it. So JSM remembers what you deployed, and refuses a later change that edits a deployed version, or deletes one whose documents may still be out there. It still allows the safe additions: new test documents, new versions, and new exceptions.

The [scenario pages](scenarios/index.md) show what JSM checks while you write a schema. This page shows what it checks once you have shipped it, on the same families. In about ten minutes, you record a deployment, then try each kind of change, and see which JSM lets through.

Every step on this page is replayed automatically, on every change to this repo, by [`scripts/replay-deployed-versions.sh`](../scripts/replay-deployed-versions.sh). The replay checks each step's outcome, whether JSM passes or fails it, and one key line of its output, so the build fails if either changes. The other lines quoted here are not checked, and may read differently in a later JSM release.

## Contents <!-- omit in toc -->

- [How JSM knows what you deployed](#how-jsm-knows-what-you-deployed)
- [Before you start: a throwaway clone](#before-you-start-a-throwaway-clone)
- [Step 1: record a deployment](#step-1-record-a-deployment)
- [Step 2: a deployed version can't change](#step-2-a-deployed-version-cant-change)
- [Step 3: but it can gain test documents, and the family new versions](#step-3-but-it-can-gain-test-documents-and-the-family-new-versions)
- [Step 4: deleting a deployed version](#step-4-deleting-a-deployed-version)
- [Step 5: a deployed version's exceptions](#step-5-a-deployed-versions-exceptions)
- [Step 6: dev allows what prod refuses](#step-6-dev-allows-what-prod-refuses)
- [Running this in CI](#running-this-in-ci)
- [What you have seen](#what-you-have-seen)

## How JSM knows what you deployed

Two commands do it:

- **`jsm tag-deployment <env>`** records a deployment to an environment, as a git tag, `jsm-deploy/<env>/<timestamp>`, on the commit you deployed. Your pipeline runs it after each successful deployment.
- **`jsm check-changes <env>`** compares the registry with the newest such tag. In an environment that doesn't allow schema mutation, it refuses each change that would break a promise made by that deployment. Your pipeline runs it on each pull request.

The registry's config, [`registry/json-schema-manager-config.yml`](../registry/json-schema-manager-config.yml), names two environments. `prod` is the production environment, and doesn't allow schema mutation. `dev` sets `allowSchemaMutation: true`, so that a team can iterate on a schema there before the contract is locked down.

## Before you start: a throwaway clone

You need [Go](https://go.dev/dl/) 1.27.3 or later, [git](https://git-scm.com/downloads) with your name and email set, since a deployment tag records who made it, and a clone of this repo.

The steps make deployment tags. Make them in a throwaway clone, so that your own clone never has one:

```sh
git clone . "${TMPDIR:-/tmp}/jsm-deployed"
cd "${TMPDIR:-/tmp}/jsm-deployed"
```

Run every other command on this page from there. As on the other pages, every command passes `-r registry`, and `validate` passes `-C`. The quoted output shortens the clone's path to `/path/to/jsm-deployed`.

Each step edits the registry by hand. To get back to the deployed state at any time, run:

```sh
git restore registry && git clean -fd registry
```

## Step 1: record a deployment

Suppose the whole registry, as it stands, has just been deployed to `prod`, and to `dev`. Record both:

```sh
go tool jsm -r registry tag-deployment prod --no-push
go tool jsm -r registry tag-deployment dev --no-push
```

Each exits 0, and names its tag:

```text
🏷️  Tagged deployment locally (not pushed): jsm-deploy/prod/20261107-181108
🏷️  Tagged deployment locally (not pushed): jsm-deploy/dev/20261107-181108
```

`--no-push` keeps the tag in this clone. A real pipeline leaves it off, so the tag goes to `origin`, where every later run can find it.

Nothing has changed since the deployment, so the check passes, with exit code 0:

```sh
go tool jsm -r registry check-changes prod
```

```text
All changes are valid
```

## Step 2: a deployed version can't change

A tidy-up improves a description in the retained-stream family's `1.1.0`. In `registry/order/placed/1/1/0/order_placed_1_1_0.schema.json`, change the description of `currency`:

```json
"currency": { "type": "string", "description": "An ISO 4217 currency code, such as GBP." }
```

It breaks no rule: `validate` still passes. But `1.1.0` is deployed:

```sh
go tool jsm -r registry check-changes prod
```

It fails, with exit code 1:

```text
Error: cannot modify deployed schemas or their test documents: [/path/to/jsm-deployed/registry/order/placed/1/1/0/order_placed_1_1_0.schema.json]
```

A deployed version is published under its version number, and readers have it. A changed schema under the same number would mean two different contracts with one name, so JSM refuses any change at all, however harmless. Make the change in a new version instead.

Undo the edit:

```sh
git restore registry && git clean -fd registry
```

The same goes for a deployed version's test documents, since they are its record of what it accepts and rejects. Change a test document of the config-file family's `1.0.0`. In `registry/deployer/settings/1/0/0/pass/with-timeout.json`, change the timeout:

```json
{ "target": "production", "timeout": 600 }
```

```sh
go tool jsm -r registry check-changes prod
```

It fails, with exit code 1:

```text
Error: cannot modify deployed schemas or their test documents: [/path/to/jsm-deployed/registry/deployer/settings/1/0/0/pass/with-timeout.json]
```

Undo the edit:

```sh
git restore registry && git clean -fd registry
```

## Step 3: but it can gain test documents, and the family new versions

Adding is safe: it changes no promise a deployment made. Capture another sample from the carrier, for the third-party-format family's deployed `1.0.0`, as `registry/carrier/tracking/1/0/0/pass/delivered.json`:

```json
{ "parcelId": "PX-0044", "status": "delivered" }
```

And start a new version of the order response:

```sh
go tool jsm -r registry create-schema-version order_response_1_1_0 minor
```

```text
Successfully created new schema with key: order_response_1_2_0
```

Check:

```sh
go tool jsm -r registry check-changes prod
```

It passes, with exit code 0:

```text
All changes are valid
```

Undo both:

```sh
git restore registry && git clean -fd registry
```

## Step 4: deleting a deployed version

Whether a deployed version may be deleted depends on how long its documents live, which the family's scenario says. Deleting the schema of a document that may still be read would leave that document with no schema.

The config-file family's settings files live for years. Delete its `1.0.0`:

```sh
rm -r registry/deployer/settings/1/0/0
go tool jsm -r registry check-changes prod
```

It fails, with exit code 1:

```text
Error: cannot delete a deployed version: /path/to/jsm-deployed/registry/deployer/settings/1/0/0: this family's documents live indefinitely, so documents written under 1.0.0 may still be read, and would have no schema
```

Undo it:

```sh
git restore registry && git clean -fd registry
```

The retained-stream family's events live 30 days. Delete its `1.0.0`:

```sh
rm -r registry/order/placed/1/0/0
go tool jsm -r registry check-changes prod
```

It fails too, with exit code 1, because its `family.yml` still says `oldestLive: 1.0.0`:

```text
Error: cannot delete a deployed version: /path/to/jsm-deployed/registry/order/placed/1/0/0: 1.0.0 is not below this family's oldestLive 1.0.0, so its documents may still exist. Once they can't, move oldestLive forward
```

Thirty days after the last `1.0.0` event was written, none is left in the log. Keep the deletion, and in `registry/order/placed/family.yml`, move `oldestLive` forward in the same change, as the [retained-stream page](scenarios/retained-stream.md#let-the-old-events-expire) does:

```yaml
oldestLive: 1.1.0
```

```sh
go tool jsm -r registry check-changes prod
```

It passes, with exit code 0:

```text
All changes are valid
```

A deployed family's `family.yml` is fixed otherwise: moving `oldestLive` forward and changing a migration statement are the only changes `check-changes` allows to it. A family whose documents are read and gone, such as the order API's, may delete any deployed version that nobody uses any more.

Undo it:

```sh
git restore registry && git clean -fd registry
```

## Step 5: a deployed version's exceptions

The registry has one family made for this step, [`registry/customer/summary/`](../registry/customer/summary/), an `owner-writes` family, like the [order response](scenarios/owner-writes.md). Its `1.0.0` limited a customer's name to 50 characters, and that was a mistake: real names are longer. `1.1.0` raised the limit to 100. That is a loosening, which `owner-writes` forbids, so `1.1.0` lists the breaks it makes on purpose, each with its reason, in its [`compat-exceptions.yml`](../registry/customer/summary/1/1/0/compat-exceptions.yml):

```yaml
exceptions:
  - version: 1.0.0
    document: fail/too-long.json
    rule: no-loosening
    reason: 1.0.0 wrongly rejected names over 50 characters.
  - version: 1.0.0
    document: pass/long-name.json
    rule: no-loosening
    reason: 1.1.0 sends names of up to 100 characters, which 1.0.0 wrongly rejected.
```

The [getting-started walk-through](getting-started.md#step-6-an-aside-a-deliberate-exception) explains exceptions. Here, `1.1.0` is deployed, and its exceptions with it.

### A deployed version may gain an exception

A new customer's name is longer still. Capture it as a sample, `registry/customer/summary/1/1/0/pass/longer-name.json`:

```json
{ "customerId": "cus-2026-9012", "name": "Pablo Diego José Francisco de Paula Juan Nepomuceno Ruiz Picasso" }
```

```sh
go tool jsm -r registry validate all -C
```

It fails, with exit code 1, because a client still on `1.0.0` rejects it:

```text
[FAIL] customer_summary_1_1_0.schema.json (pass: 3, fail: 1, excepted: 2)
  ✗ /path/to/jsm-deployed/registry/customer/summary/1/1/0/pass/longer-name.json (no-loosening broken: pass document of 1.1.0 rejected by 1.0.0):
```

It is the same deliberate break, so add an entry for it to the end of `1.1.0`'s `compat-exceptions.yml`, which then reads:

```yaml
exceptions:
  - version: 1.0.0
    document: fail/too-long.json
    rule: no-loosening
    reason: 1.0.0 wrongly rejected names over 50 characters.
  - version: 1.0.0
    document: pass/long-name.json
    rule: no-loosening
    reason: 1.1.0 sends names of up to 100 characters, which 1.0.0 wrongly rejected.
  - version: 1.0.0
    document: pass/longer-name.json
    rule: no-loosening
    reason: 1.1.0 sends names of up to 100 characters, which 1.0.0 wrongly rejected.
```

`validate` now passes, with exit code 0, and shows the run as excepted:

```text
  ~ /path/to/jsm-deployed/registry/customer/summary/1/1/0/pass/longer-name.json (no-loosening excepted: pass document of 1.1.0 rejected by 1.0.0):
    reason: 1.1.0 sends names of up to 100 characters, which 1.0.0 wrongly rejected.
```

And the change is allowed on a deployed version:

```sh
go tool jsm -r registry check-changes prod
```

```text
All changes are valid
```

A new test document and a new entry add to the record, and change nothing that was deployed. This is also the way out when a new check finds a break in a version that's already deployed: list it, with a reason.

Undo both:

```sh
git restore registry && git clean -fd registry
```

### But an entry that was deployed can't change

Someone rewords the first entry's reason. In `registry/customer/summary/1/1/0/compat-exceptions.yml`, change it to:

```yaml
reason: Names over 50 characters were always valid, and 1.0.0 was wrong to reject them.
```

```sh
go tool jsm -r registry check-changes prod
```

It fails, with exit code 1:

```text
Error: cannot change a deployed exception: /path/to/jsm-deployed/registry/customer/summary/1/1/0/compat-exceptions.yml: the entry for version 1.0.0, fail/too-long.json, no-loosening can't be edited, or removed while it clears something
```

An entry is reviewed once, when it is added, and then locked, as the schema is. Only an entry that clears nothing any more may go.

## Step 6: dev allows what prod refuses

Keep the edit, and check it against `dev` instead:

```sh
go tool jsm -r registry check-changes dev
```

It passes, with exit code 0:

```text
All changes are valid
```

`dev` allows schema mutation, so every edit on this page that `prod` refused passes there. That lets a team change a schema freely while it's only in `dev`, before the contract is locked down in `prod`.

When you're done, leave the clone and delete it, with its tags:

```sh
cd -
rm -rf "${TMPDIR:-/tmp}/jsm-deployed"
```

## Running this in CI

`check-changes` needs the deployment tags, and the history back to them. CI systems often clone only the latest commit, without tags. In GitHub Actions, check out with `fetch-depth: 0`. In a shallow clone without the tag, `check-changes` fails with exit code 2, rather than guess. With no deployment tag at all, it treats every schema as new, and passes.

JSM's docs show a whole pipeline, which runs `check-changes prod` on each pull request, and deploys and runs `tag-deployment prod` on the main branch. See [Running JSM in CI](https://github.com/bitshepherds/json-schema-manager/blob/v2.0.0/user-docs/developing-schemas.md#running-jsm-in-ci) and [Git history in CI](https://github.com/bitshepherds/json-schema-manager/blob/v2.0.0/user-docs/developing-schemas.md#git-history-in-ci).

This repo deploys nothing, so it has no deployment tags of its own.

Some of the output on this page will read better in a later JSM release: the paths are absolute, and long ([bitshepherds/json-schema-manager#156](https://github.com/bitshepherds/json-schema-manager/issues/156)), and `(pass: 3, fail: 1, excepted: 2)` counts runs, not documents ([bitshepherds/json-schema-manager#154](https://github.com/bitshepherds/json-schema-manager/issues/154)).

## What you have seen

- **`tag-deployment`** records what was deployed to an environment, and **`check-changes`** holds each later change to it.
- **A deployed version is frozen.** Its schema and its test documents can't change, however harmless the change.
- **Adding is allowed:** new test documents, new versions, and new exception entries.
- **Deleting follows the scenario.** A version whose documents may still be read can't go: never in a config-file family, and not at or above `oldestLive` in a retained stream.
- **An exception, once deployed, is locked**, like the schema it excuses.
- **An environment that allows mutation**, such as `dev`, lets a team iterate before the contract is locked.
