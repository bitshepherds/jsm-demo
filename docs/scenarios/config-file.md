# Config files: a tool's settings file

Scenario `config-file`. [All scenarios](index.md) · [JSM's page on this scenario](https://github.com/bitshepherds/json-schema-manager/blob/v2.0.0/user-docs/scenarios.md#3-config-files)

A tool owns its settings file and reads it, and people write it, then keep it in their repositories for years. When a team upgrades the tool, a settings file that has worked for three years must still load. So a new version must never refuse a file an older version accepted, and when a change does need old files rewritten, someone has to say how.

## Who owns it, who follows, who moves first

- **Owner:** the deployer, a deployment tool, whose team decides which options its settings file has.
- **Followers:** the people who write settings files for it, by hand.
- **Who moves first:** the owner, with each new release of the tool. Teams upgrade when they choose, and their old files come with them.

## The worked example

The family is [`registry/deployer/settings/`](../../registry/deployer/settings/). Its [`family.yml`](../../registry/deployer/settings/family.yml) declares the scenario, and says how files move to major version 2:

```yaml
scenario: config-file
# A family whose files live for years needs a statement, for each major past the first, of how files move to it.
# JSM checks only that it is here.
migrations:
  2: The deployer's upgrade command renames timeout to timeoutSeconds in each settings file it finds.
```

| Version | What it holds |
| --- | --- |
| `1.0.0` | A `target`, and an optional `timeout`. It is closed: a mistyped option, such as `timout`, is an error rather than silently ignored. |
| `1.1.0` | Adds an optional `parallel`. That is the safe change, and it is green. |
| `2.0.0` | Renames `timeout` to `timeoutSeconds`. A rename breaks old files, so it is a new major version, with the migration statement above. |

Adding an option harms no one: every old file still loads. A file using `parallel` would fail on a `1.0.0` deployer, but that needs an old tool reading a new file, and the scenario doesn't promise that. JSM proves the safe direction by running `1.0.0`'s pass document on `1.1.0`:

```sh
go tool jsm -r registry validate all -C
```

```text
[PASS] deployer_settings_1_1_0.schema.json (pass: 4, fail: 0)
[PASS] deployer_settings_2_0_0.schema.json (pass: 2, fail: 0)
```

No document crosses a major version, so `2.0.0` is free to rename the option. Its own fail document, a file that still says `timeout`, proves `2.0.0` refuses it.

## Break it

Someone tries the rename in a minor version instead. In `registry/deployer/settings/1/1/0/deployer_settings_1_1_0.schema.json`, rename the option:

```json
"timeoutSeconds": { "type": "integer", "minimum": 1 },
```

Validate:

```sh
go tool jsm -r registry validate all -C
```

It fails, with exit code 1:

```text
[FAIL] deployer_settings_1_1_0.schema.json (pass: 3, fail: 1)
  ✗ /path/to/jsm-demo/registry/deployer/settings/1/0/0/pass/with-timeout.json (no-tightening broken: pass document of 1.0.0 rejected by 1.1.0):
    no-tightening broken between deployer_settings_1_0_0 and deployer_settings_1_1_0: pass document /path/to/jsm-demo/registry/deployer/settings/1/0/0/pass/with-timeout.json of deployer_settings_1_0_0 was rejected by deployer_settings_1_1_0. In a config-file family, a reader on deployer_settings_1_1_0 rejects a document written under deployer_settings_1_0_0, which may still be around. Undo the change, or make it in a new major version. ...
- at '': additional properties 'timeout' not allowed
```

A team's file, `{ "target": "production", "timeout": 300 }`, loaded yesterday. After the upgrade, `1.1.0` refuses it. That is a **tightening**.

Undo the edit:

```sh
git restore registry
```

### Break it another way: leave out the migration statement

Files written for major version 1 are still in people's repositories when `2.0.0` ships, and JSM can't move them for you. So it asks you to say how they move. In `registry/deployer/settings/family.yml`, delete the statement, both of these lines:

```yaml
migrations:
  2: The deployer's upgrade command renames timeout to timeoutSeconds in each settings file it finds.
```

Validate:

```sh
go tool jsm -r registry validate all -C
```

It fails, with exit code 1, under the new major's first version:

```text
[FAIL] deployer_settings_2_0_0.schema.json (pass: 2, fail: 0)
  ✗ major 2 needs a migration statement: in a config-file family old documents stay around, and a major bump doesn't make them vanish. Add a sentence or link to family.yml saying how old documents move to it, with "migrations:" and under it "2: <how they move>". A migration is your own code: JSM only checks the statement is there.
```

Undo the edit:

```sh
git restore registry
```

The output above shortens the paths to `/path/to/jsm-demo`: JSM prints them in full ([bitshepherds/json-schema-manager#156](https://github.com/bitshepherds/json-schema-manager/issues/156)). The counts in brackets count runs, not documents ([#154](https://github.com/bitshepherds/json-schema-manager/issues/154)).

## What JSM checks, and what it leaves to you

JSM checks, within a major version:

- **No tightening.** Each earlier version's pass documents run on every later version, and each later version's fail documents run on every earlier version. A later version may not refuse a file an earlier one accepted.
- **Each version's own documents**, as in every scenario.
- **A migration statement for each major past the first**, in `family.yml`. It checks only that the statement is there.

It leaves to you:

- **The migration itself.** The statement says how old files move. Writing the code that moves them, and testing it, is yours: JSM tests no settings files but its own test documents.
- **Old tools reading new files.** A `1.0.0` deployer refuses a file that uses `parallel`. The scenario promises old files load in new tools, not the other way round.
- **Test documents that show each change**, and a closed schema, so that typos are caught.

A settings file that names its own version, read by a tool that migrates each file itself, needs a different check. See JSM's [versioned config files](https://github.com/bitshepherds/json-schema-manager/blob/v2.0.0/user-docs/scenarios.md#variant-versioned-config-files-that-migrate), and [stored data that names its version](stored-self-naming.md).
