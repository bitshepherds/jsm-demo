# Uncoordinated parties: notes synced between devices

Scenario `uncoordinated`. [All scenarios](index.md) · [JSM's page on this scenario](https://github.com/bitshepherds/json-schema-manager/blob/v2.0.0/user-docs/scenarios.md#7-uncoordinated-parties)

Nobody controls who upgrades when, so whoever reads a document may be on an older version than whoever wrote it, or a newer one. That happens when there is no single owner, such as several teams writing to one message bus, or when the owner's own software writes and reads the documents in many copies that each upgrade when they like, such as an app that syncs notes between a person's phone and tablet. Changes are checked in both directions, so few are safe within a major version.

## Who owns it, who follows, who moves first

- **Owner:** the notes app's team, which decides what a note holds. But it can't make anyone install a new release, and every install both writes and reads notes.
- **Followers:** every install of the app.
- **Who moves first:** any install. A phone may be on the new release while the tablet is still on the old one, or the other way round.

## The worked example

The family is [`registry/notes/note/`](../../registry/notes/note/). Its [`family.yml`](../../registry/notes/note/family.yml) declares the scenario, and how long notes live:

```yaml
scenario: uncoordinated
# This scenario must say how long its documents live. Synced notes are kept for good.
documentsLive: indefinitely
```

This scenario must state `documentsLive`: how long documents live varies, so the scenario alone is refused. A synced note is kept for good. Messages on a bus that are read and gone would be `moment`. If you don't know, choose `indefinitely`, which is always accepted, and assumes the worst. Since these notes live for good, a second major version would need a migration statement, as in [config files](config-file.md).

| Version | What it holds                                                                               |
| ------- | ------------------------------------------------------------------------------------------- |
| `1.0.0` | A `noteId`, its `text`, a `state` of `active` or `archived`, and an optional `updatedAt`.   |
| `1.1.0` | Adds a description of the note, and nothing more. That is the safe change, and it is green. |

JSM runs all four kinds of run across the two versions:

```sh
go tool jsm -r registry validate all -C
```

```text
[PASS] notes_note_1_1_0.schema.json (pass: 6, fail: 0)
```

## Break it

The app's team wants to sort notes by when they were last edited. In `registry/notes/note/1/1/0/notes_note_1_1_0.schema.json`, make `updatedAt` required:

```json
"required": ["noteId", "text", "state", "updatedAt"]
```

Validate:

```sh
go tool jsm -r registry validate all -C
```

It fails, with exit code 1:

```text
[FAIL] notes_note_1_1_0.schema.json (pass: 5, fail: 1)
  ✗ /path/to/jsm-demo/registry/notes/note/1/0/0/pass/shopping-list.json (no-tightening broken: pass document of 1.0.0 rejected by 1.1.0):
    no-tightening broken between notes_note_1_0_0 and notes_note_1_1_0: pass document /path/to/jsm-demo/registry/notes/note/1/0/0/pass/shopping-list.json of notes_note_1_0_0 was rejected by notes_note_1_1_0. In a uncoordinated family, a reader on notes_note_1_1_0 rejects a document written under notes_note_1_0_0, which may still be around. Undo the change, or make it in a new major version. ...
- at '': missing property 'updatedAt'
```

The tablet, still on `1.0.0`, syncs `{ "noteId": "note-17", "text": "Milk, eggs, bread", "state": "active" }` to the phone, on `1.1.0`, which refuses it. That is a **tightening**. The other direction breaks too: had `1.1.0` added a `pinned` state instead, the phone would sync a pinned note to the tablet, which refuses it. `1.0.0`'s fail document, a note whose state is `pinned`, is there to catch that **loosening**.

Undo the edit:

```sh
git restore registry
```

The output above shortens the paths to `/path/to/jsm-demo`: JSM prints them in full ([bitshepherds/json-schema-manager#156](https://github.com/bitshepherds/json-schema-manager/issues/156)). "a uncoordinated" will read "an uncoordinated" ([#153](https://github.com/bitshepherds/json-schema-manager/issues/153)), and the counts in brackets count runs, not documents ([#154](https://github.com/bitshepherds/json-schema-manager/issues/154)).

## What JSM checks, and what it leaves to you

JSM checks, within a major version:

- **No loosening and no tightening.** All four runs across versions take place.
- **Each version's own documents**, as in every scenario.
- **A change that no document shows**, in either direction, with a warning.
- **That the family states `documentsLive`**, and, where documents live for good, a migration statement for each major past the first.

It leaves to you:

- **How long documents really live.** JSM takes your word for it.
- **Documents that catch each change.** Checking both ways is only as strong as the documents. An open schema that adds a typed optional field is strictly a tightening, and passes unless a document happens to use the wrong type there. See JSM's ["Either" is only as strong as its samples](https://github.com/bitshepherds/json-schema-manager/blob/v2.0.0/user-docs/scenarios.md#either-is-only-as-strong-as-its-samples).
