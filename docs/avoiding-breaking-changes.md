# Avoiding breaking changes <!-- omit in toc -->

- [What breaks a consumer](#what-breaks-a-consumer)
- [Changes which look safe, but are not](#changes-which-look-safe-but-are-not)
  - [Adding an enum value](#adding-an-enum-value)
  - [Relaxing a constraint](#relaxing-a-constraint)
  - [Allowing another type](#allowing-another-type)
  - [Making a property optional](#making-a-property-optional)
  - [Adding a property to a closed object](#adding-a-property-to-a-closed-object)
- [Changes which are safe in a minor version](#changes-which-are-safe-in-a-minor-version)
- [How JSM catches breaking changes](#how-jsm-catches-breaking-changes)
- [When a change must break](#when-a-change-must-break)

## What breaks a consumer

A provider moves to a new schema version first, while its consumers still validate against an earlier one. So a change breaks consumers if the new version accepts a document which an earlier version rejects: the provider sends it, and the consumer rejects it.

That gives one rule for a minor or patch version: **it must accept nothing which an earlier version with the same major version rejects.** See [Decoupled services, data evolution, and semantic versioning](./decouple.md) for why.

## Changes which look safe, but are not

Each of these widens what the schema accepts, so each needs a new major version.

### Adding an enum value

```json
"status": { "enum": ["pending", "completed", "failed"] }
```

Adding `"refunded"` looks like a small feature, but a consumer on the earlier version rejects every refunded payment. If you expect a list of values to grow, consider a plain `string`, and have consumers handle values they don't know.

### Relaxing a constraint

Raising a `maxLength` from 10 to 20, lowering a `minimum`, or removing or loosening a `pattern` lets the provider send values the earlier version rejects. Choose limits which leave room to grow before the first version is deployed.

### Allowing another type

Changing `"type": "string"` to `"type": ["string", "null"]` lets the provider send `null`, which the earlier version rejects. Decide early whether a property can be null.

### Making a property optional

Removing a property from `required` lets the provider leave it out, and the earlier version rejects documents without it. Only require what every version will always send.

### Adding a property to a closed object

With `"additionalProperties": false`, an object accepts only the properties it declares. Adding one in a later version lets the provider send it, and the earlier version rejects it. Only close an object which will never gain a property, such as a WGS-84 location.

## Changes which are safe in a minor version

- Adding an optional property to an object which allows additional properties, the JSON Schema default. Consumers on the earlier version accept it, and should ignore properties they don't know.
- Tightening a constraint, such as lowering a `maxLength`: everything the new version accepts, the earlier one accepts too.
- Improving a `title`, `description` or `examples`, which change nothing that is accepted. These suit a patch version.

## How JSM catches breaking changes

- **The compatibility check.** `jsm validate` runs each version's passing test documents against every earlier version with the same major version, and fails if one rejects them. Write a passing document which uses each new feature, such as the new enum value, and the check catches the break.
- **Unexercised changes.** The check is only as strong as the passing documents, so `jsm validate` also compares each version with the one before it, and warns about each change which may break consumers and which no passing document uses:

  ```text
  [WARN] finance_payments_payment-instruction_1_3_0.schema.json since finance_payments_payment-instruction_1_2_0:
    ! /status: enum adds "refunded" (widens)
  ```

  Add a passing document which uses the change, and the compatibility check then tells you whether it breaks.

- **`jsm diff <older> <newer>`** lists every structural change between two versions, marked `widens`, `narrows` or `alters`, and which passing documents use each.
- **`--strict`** makes `jsm validate` fail on these warnings, for CI.

## When a change must break

Sometimes a breaking change is the right one. Make it a new major version, with `jsm create-schema-version <schema> major`. The provider sends the old and new versions side by side, while each consumer moves to the new one during a deprecation window. A consumer which lists its versions in a `jsm-consumer.yml` file, and runs `jsm check-consumer`, is warned when a newer major version appears.
