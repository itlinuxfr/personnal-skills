---
name: helm-chart-docs
description: Generates or updates the README of a Helm chart with helm-docs, keeping the chart's existing layout, wording and language. Use when asked to document a chart, to write, regenerate or update its README or its values table, to set up helm-docs on a chart, or to fix the documentation findings of a review (README content, undocumented values, accepted deviations).
argument-hint: <chart path>
compatibility: Requires helm-docs, helm, git and a bash shell.
---

# Chart documentation

The README is produced by `helm-docs` from two sources kept in the chart:

- `README.md.gotmpl` — the layout and everything written by hand (purpose,
  examples, notes);
- `values.yaml` — one `# --` comment per key, which becomes the values table.

`README.md` is a generated file: once the template exists, never edit it by hand.

You change documentation only. You never rename a key, change a default value or
touch a template in `templates/`.

## 1. Load the references

- `${CLAUDE_SKILL_DIR}/../_shared/references/method.md` — standing rules, language,
  git;
- `${CLAUDE_SKILL_DIR}/../_shared/references/standard.md` — STR-06 and VAL-03 are
  the rules this skill serves.

## 2. Find helm-docs

```bash
command -v helm-docs || mise which helm-docs
```

Use the path found. If there is none, say so and stop: install nothing. Offer to
update the README by hand instead, following STR-06.

## 3. Take stock

Read `Chart.yaml`, `values.yaml`, the templates, the current `README.md` and
`README.md.gotmpl` if there is one. Then pick the case:

| Situation | What you do |
|---|---|
| `README.md.gotmpl` exists | Update it and the values comments (step 5), regenerate |
| `README.md` exists, no template | Migrate it (step 4), then regenerate |
| No README | Start from [assets/README.md.gotmpl](assets/README.md.gotmpl), then regenerate |

If other charts in the repository already have a `README.md.gotmpl`, or the
repository has a shared template file, follow that layout rather than the asset.

## 4. Migrate an existing README

The existing README is the model: keep its headings, their order, its wording and
its language. The author's format wins over the asset's.

1. Copy `README.md` to `README.md.gotmpl`.
2. Replace only what helm-docs can produce:
   - the chart name in the title → `{{ template "chart.name" . }}`;
   - a hand-written table of values → the generated table (see the asset for a
     table with custom column titles; translate the titles to the README's
     language).
3. Leave every hand-written section as it is: description, components, examples,
   notes.
4. A literal `{{` in the prose (a Helm snippet in an example) must be escaped as
   `{{ "{{" }}`, otherwise helm-docs fails.

Do not remove a section because it overlaps the generated table (for instance a
commented YAML skeleton of the values): it usually documents what the table
cannot, such as the fields of list items. Point out a real duplicate and let the
user decide.

## 5. Bring the content up to date

**Values comments (VAL-03).** helm-docs only reads comments that start with
`# --`, placed just above the key:

```yaml
egressIP:
  # -- Creates the EgressIP resources, one per zone.
  enabled: false
  # -- Zones. Each one produces an EgressIP for namespaces labelled `region: <name>`.
  # @default -- `[]` (no zone)
  zones: []
```

- Turn each existing comment into a `# --` comment; write the missing ones from
  what the template does with the key, in the language of the file.
- `# @default --` replaces the displayed default when the real one is unreadable
  (a long list, an empty object).
- Only keys present in `values.yaml` reach the table. The fields of the items of
  a list that is empty by default (`zones[].name`) do not: describe them in the
  comment of the list itself, and keep or write a hand-written section showing
  the structure of an item. Never add a fake item to the defaults to get a row.
- Changing comments does not change the rendered chart: class A.

**Required content (STR-06).** The template must contain, under the headings the
chart already uses or the asset's:

- the purpose of the chart;
- prerequisites with versions: operator, expected CRDs, cluster labels;
- the resources produced;
- the values table;
- accepted deviations, when there are any: rule, what is done instead, reason;
- what to know before changing or deleting: immutable fields, effect of a
  deletion.

Write only what is confirmed by the chart or by a source; ask for the rest.

**After a review.** Take its documentation findings one by one: STR-06 (missing
section), VAL-03 (undocumented key), VAL-04 (key read but not declared — declare
it only if the user asks, that is a values change), and any class C decision the
user has settled, which becomes an accepted deviation.

## 6. Generate

Preview, then write:

```bash
helm-docs --chart-search-root <chart> --sort-values-order file --dry-run
helm-docs --chart-search-root <chart> --sort-values-order file
```

`--sort-values-order file` keeps the order of `values.yaml`. Do not rely on
`--documentation-strict-mode`: in helm-docs 1.14 it reports documented keys too
and exits with code 0.

Then:

- add `README.md.gotmpl` to `.helmignore`, otherwise it ships in the package;
- read `git diff --ignore-cr-at-eol -- <chart>/README.md`: every removed line must
  be accounted for (moved, regenerated, or dropped on purpose). On a migration, a
  section that vanished is a mistake in the template. helm-docs writes Unix line
  endings: a README that had Windows ones shows every line as changed without
  that option; tell the user the line endings were converted;
- run helm-docs a second time: the file must not change;
- `helm lint --strict <chart>`.

Paste the commands and the diff in your reply.

## 7. Wrap up

- Documentation does not change the rendered chart: class A, patch version
  (REL-01).
- A changelog entry under `[Unreleased]` if the README gained information a user
  needs (REL-02).
- On the approved working branch: one commit `<chart>: STR-06 <what changes>`,
  containing the template, the values comments, the generated README and
  `.helmignore`.
- Summarise: what is generated, what stays hand-written and where to edit it, what
  could not be documented for lack of a source.
