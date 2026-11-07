# Scenarios: how your schema is used decides what's safe

Which changes to a schema are safe depends on how it is used. A settings file people keep for years needs different care from an API response that is read once and gone. JSM knows nine such situations, its **scenarios**. Each family of schemas in a registry names its scenario in its `family.yml`, and that decides what JSM checks when the family gets a new version.

Each page below takes one scenario, in plain words, with a worked example on a real family in this repo's [`registry/`](../../registry/). You make a safe change and a breaking one, run JSM, and see what it checks for you, and what it leaves to you. Find the situation you're in, and start there. If you're new to JSM, start with the [getting-started walk-through](../getting-started.md) instead: it covers the first two scenarios in more depth.

## Choose your scenario

Start with who owns the contract: the one party that decides what the schema says, and changes it. Everyone else follows it, and catches up later. Then answer these in order, and stop at the first that fits. An API's request and response are two families, one for each.

1. **Does another organisation own the format, so your schema only records what it sends?** [A format someone else owns](third-party-format.md).
2. **Does each document name its own version, and is it checked against that version only?** [Stored data, each document names its version](stored-self-naming.md).
3. **Does one team own both sides, and release the writer and the reader together, with no documents kept beyond the release?** [Lock-step](lock-step.md).
4. **Do documents stay around for good?**
   - Settings files that people edit, read by the tool that owns them: [config files](config-file.md).
   - Records a service saves and reads back: [stored data, one schema for all](stored-one-schema.md).
   - Documents shared between copies of an app that each upgrade when their users like: [uncoordinated parties](uncoordinated.md).
5. **Are documents kept for a set period, and can they be read again?** [Retained streams](retained-stream.md).
6. **Otherwise, documents are read and gone.**
   - The owner writes them, and its followers read them: [owner writes](owner-writes.md).
   - The owner reads them, and its followers write them: [owner reads](owner-reads.md).
   - There's no single owner, or the reader may be behind the writer as well as ahead: [uncoordinated parties](uncoordinated.md).

## The nine scenarios

| Scenario | For example | This repo's family | JSM refuses a change that… |
| --- | --- | --- | --- |
| [`owner-writes`](owner-writes.md) | An API's response | [`order/response`](../../registry/order/response/) | loosens: accepts what an earlier version rejected |
| [`owner-reads`](owner-reads.md) | An API's request | [`order/request`](../../registry/order/request/) | tightens: rejects what an earlier version accepted |
| [`config-file`](config-file.md) | A tool's settings file | [`deployer/settings`](../../registry/deployer/settings/) | tightens, or starts a major with no migration statement |
| [`stored-one-schema`](stored-one-schema.md) | Customer records in a database | [`customer/profile`](../../registry/customer/profile/) | tightens, or starts a major with no migration statement |
| [`stored-self-naming`](stored-self-naming.md) | Invoices stamped with a version | [`billing/invoice`](../../registry/billing/invoice/) | makes a version refuse its own documents |
| [`retained-stream`](retained-stream.md) | An event log kept for 30 days | [`order/placed`](../../registry/order/placed/) | loosens or tightens, back as far as `oldestLive` |
| [`uncoordinated`](uncoordinated.md) | Notes synced between devices | [`notes/note`](../../registry/notes/note/) | loosens or tightens |
| [`lock-step`](lock-step.md) | A file between two steps of a job | [`batch/plan`](../../registry/batch/plan/) | makes a version refuse its own documents |
| [`third-party-format`](third-party-format.md) | A carrier's webhook | [`carrier/tracking`](../../registry/carrier/tracking/) | tightens, worded as the outside format having changed |

In every scenario, each version must also accept its own pass documents and refuse its own fail documents, and no document runs across a major version: a new major version is how to make a change the scenario forbids.

Once a version is deployed, it is frozen: JSM refuses an edit to its schema, its test documents or its exception entries, and deleting it while its documents may still be read. It still allows new test documents, new exception entries and new versions, removing an exception entry that clears nothing, and two changes to `family.yml`: moving `oldestLive` forward, and changing a migration statement. How long documents live, which the scenario says, decides when a deployed version may go. [Deployed versions are frozen](../deployed-versions.md) shows it on these families.

## How each page works

Each page has the same shape:

- **Who owns it, who follows, who moves first.** That is what decides the scenario.
- **The worked example.** The family's `family.yml`, its versions, and a safe change, already made and green.
- **Break it.** A one-line edit you make by hand, the command to run, and what JSM says. Undo it with `git restore registry`.
- **What JSM checks, and what it leaves to you.**

Run every command from the repo's root folder. Each passes `-r registry`, which says where the registry is, and `validate` passes `-C`, which keeps going after a failure, so you see every result. Until [bitshepherds/json-schema-manager#158](https://github.com/bitshepherds/json-schema-manager/issues/158) is fixed, an exported `JSM_REGISTRY_ROOT_DIR` overrides the current folder, so either unset it or always pass `-r`.

Every page's breaking edit is checked automatically, on every change to this repo, by [`scripts/check-scenarios.sh`](../../scripts/check-scenarios.sh). It makes each edit in a temporary copy of the registry, and checks that JSM refuses it, names the rule the page says, and that the page quotes those lines. The other lines quoted, such as the counts, are not checked, and may read differently in a later JSM release.

JSM's own [scenarios page](https://github.com/bitshepherds/json-schema-manager/blob/v2.0.0/user-docs/scenarios.md) gives the full rule for each, and each page here links to its section.
