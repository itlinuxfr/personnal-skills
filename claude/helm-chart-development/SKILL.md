---
name: helm-chart-development
description: Creates a new Helm chart that complies with the chart standard from version 0.1.0. Use when asked to create, initialise, generate or scaffold a chart, to package an operator resource (CRD) or an application as a chart, or to write its helpers, values.yaml or values.schema.json from scratch. Not for modifying an existing chart.
argument-hint: <chart name> <what it must deploy>
---

# Chart creation

A new chart must pass `helm-chart-review` with no finding from version 0.1.0: the
standard applies while writing, not afterwards.

Do not use `helm create`: it generates a full application skeleton (Deployment,
Service, Ingress, HPA, ServiceAccount) that then has to be undone, and that does
not follow the standard.

## 1. Load the references

- `${CLAUDE_SKILL_DIR}/../_shared/references/method.md` — standing rules, language,
  git, scenarios;
- `${CLAUDE_SKILL_DIR}/../_shared/references/standard.md` — the rules;
- `${CLAUDE_SKILL_DIR}/../_shared/references/standard-pods.md` if the chart renders
  pods.

## 2. Scope before writing

Create no file before having these answers. Ask, in one go, the questions whose
answer is missing:

- **Purpose**: what must happen on the cluster once the chart is synced?
- **Resources**: which `kind` and `apiVersion`? Cluster or namespace scope?
- **Operator or application**: which one, which version, installed by whom?
- **Instances**: a single one per cluster (singleton) or several installations?
- **Name and namespace**: imposed, or free?
- **Variability**: what changes from one cluster to another? That is the only
  thing that deserves a values key.
- **Deployment**: Argo CD Application name, destination namespace, planned values
  files.
- **Location**: directory in which to create the chart.

## 3. Check the custom resources

For each `kind` outside the core Kubernetes API, establish before writing:
required fields, immutable fields, effect of a deletion, `apiVersion` served by
the targeted version. Accepted sources: `oc explain <kind> --recursive` (or
`kubectl explain`), or the official documentation for that version.

Anything no source confirms does not go into a template: say so and ask.

## 4. Write the README first

The `README.md` is the chart's specification: purpose, versioned prerequisites,
resources produced, planned values table, accepted deviations (STR-06). Template
in [references/templates.md](references/templates.md).

**Have it approved before writing any template.**

## 5. Model on what exists

If the repository has a compliant chart producing a similar resource, reuse its
conventions (naming, shape of values, comments, language). Otherwise follow the
templates in `references/templates.md`.

## 6. Generate the chart

```
<chart>/
├── Chart.yaml
├── values.yaml
├── values.schema.json
├── README.md
├── CHANGELOG.md
├── .helmignore
├── templates/
│   ├── _helpers.tpl
│   └── <lowercase kind>.yaml      one file per kind (STR-04)
└── tests/
    └── <lowercase kind>_test.yaml
```

- **`Chart.yaml`**: STR-01 and STR-02, `version: 0.1.0`.
- **`_helpers.tpl`**: copy [assets/_helpers.tpl](assets/_helpers.tpl) and replace
  `CHART` with the chart name. Add a helper only if it is used in two places.
- **Templates**: every resource gets the helper's labels (TPL-01) and a name
  derived from `fullname`, unless the name is imposed and listed in the accepted
  deviations (TPL-02). Blocks through `toYaml` + `nindent`, strings through
  `quote` (TPL-06).
- **Required values**: `required` or `fail` with a message naming the key
  (TPL-07). `required` lets an empty list or object through: for those, use
  `minItems` or `minProperties` in the schema.
- **Argo CD**: no `lookup`, no `.Release.IsUpgrade`, no random function (TPL-04).
  CRD possibly missing at sync time: sync-wave or
  `SkipDryRunOnMissingResource=true` (CRD-04). Resource whose deletion cuts a
  service: explicit behaviour (CRD-07).
- **`values.yaml`**: only what varies between clusters; every key commented
  (VAL-03), in camelCase (VAL-02). No "just in case" key.
- **`values.schema.json`**: types, required fields, unknown keys rejected
  (VAL-05).
- **Pods**: apply `standard-pods.md` while writing, in particular WKL-02 (no fixed
  UID) and WKL-08 (selector labels).
- **Tests**: one `helm unittest` suite per template, following the
  `helm-chart-testing` skill.

## 7. Verify

```bash
helm lint --strict <chart>
helm template <release> <chart> --namespace <ns>
helm template <release> <chart> --namespace <ns> -f <scenario values>
helm unittest <chart>
```

The default render must succeed, or fail with a clear `required` message (VAL-07).
Re-read every rendered resource field by field against what step 3 established.
Paste the commands and their output in your reply.

Also trigger two errors: a missing required value and an unknown key must both
fail the render with an understandable message.

## 8. Self-review

Go through every rule of the standard. Fix any finding now; what is an accepted
deviation goes into the README. The goal is that a `helm-chart-review` run
afterwards finds nothing.

## 9. Wrap up

- `CHANGELOG.md`: `## 0.1.0 — <date>` then `- Initial release.`
- On the approved working branch: one commit `<chart>: initial release 0.1.0`.
- Summarise: resources produced, values keys exposed, points not verified, and
  what remains to be done on the Argo CD side (Application, values files).
- No push and no pull request without a request.
