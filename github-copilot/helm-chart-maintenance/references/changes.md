# Evolving a chart

## Choosing the version (REL-01)

The version announces the risk to whoever deploys. The **cumulative render diff**
decides, not the amount of work.

| What changed | Version | Examples |
|---|---|---|
| Identical output on every scenario | Patch | README, comments, factored helper, tests |
| Rendered content changed, or new optional key | Minor | Added label, annotation, `values.schema.json`, new option disabled by default |
| Values contract or resource identity changed | Major | Key renamed or removed, default value that changes behaviour, resource renamed |

A schema or a `required` that rejects values accepted until now is at least a
minor; say so in the changelog, it is what surprises people on upgrade.

`appVersion` does not follow the chart version: it changes only when the version
of the targeted operator or component changes (STR-02).

## Renaming, moving or removing a key (VAL-01, class C)

Always over two versions, never one.

**Minor version — the old key still works.**

The template reads the new key and falls back on the old one:

```yaml
{{- $repo := .Values.image.repository | default .Values.image.name -}}
```

`default` and `coalesce` ignore `false`, `0` and `""`. For a boolean or a number,
test whether the key is present:

```yaml
{{- $enabled := .Values.newKey -}}
{{- if hasKey .Values "oldKey" }}{{ $enabled = .Values.oldKey }}{{ end -}}
```

The old key stays in `values.yaml` with a comment
`# Deprecated: use <new key>. Removed in <major version>.`, and in the schema.
README and changelog announce it.

With Argo CD there is no such thing as a render-time warning: `NOTES.txt` is not
displayed and `fail` stops the sync. Deprecation is therefore read in the
changelog and the README, nowhere else.

**Major version — the old key is removed.**

A `fail` naming both keys replaces the read of the old one:

```yaml
{{- if hasKey .Values.image "name" }}
{{- fail "image.name was removed: use image.repository" }}
{{- end }}
```

The render diff must be empty for scenarios already migrated. Every scenario still
using the old key is listed in the report: it will fail.

## Updating a dependency (STR-03)

```bash
helm dependency list <chart>
# change the exact version in Chart.yaml, then:
helm dependency update <chart>
```

- Exact version in `Chart.yaml`, never a range (`12.x.x`, `^12.0.0`).
- `Chart.lock` is committed in the same commit.
- It is a class B fix: the render diff shows what the new version changes. A major
  upgrade of the dependency is read in its own changelog before being applied.
- To compare, run `helm dependency build` in the reference copy (see `method.md`).

## Maintaining the changelog (REL-02)

The format is [Keep a Changelog](https://keepachangelog.com):

```markdown
# Changelog

## [Unreleased]

### Fixed
- Egress IPs are now quoted, so an address is never read as a number.

## [1.1.0] - 2026-10-11

### Added
- EgressIPs are no longer deleted when a zone is removed from the values
  (`Prune=false`); delete them manually.

### Removed
- **Breaking:** `image.name` is removed, use `image.repository`.
```

- Write for whoever deploys the chart: what changes for them and what they must
  do. No rule ID: it goes in the commit message.
- Sections, in this order when present: `Added`, `Changed`, `Deprecated`,
  `Removed`, `Fixed`, `Security`.
- A change with no effect on the rendered output (class A) gets an entry only if
  it matters to a user: documentation, schema, tests are worth a line; an
  internal helper refactoring is not.
- A change that breaks existing values starts with `**Breaking:**` and says how
  to migrate.
- Dates are `YYYY-MM-DD`. Releasing a version renames `[Unreleased]` and opens a
  new empty one.

A chart whose changelog uses another format is an REL-02 finding: converting it
is a class A fix of its own, not something to do while fixing another rule.

## Origin

Version table, deprecation cycle and dependency handling adapted from
`foxj77/claude-code-skills` (`helm-chart-maintenance`, MIT license). Deliberate
differences: dependencies pinned to an exact version, and no `fail` presented as
a warning.
