---
name: helm-chart-review
description: Audits a Helm chart without modifying it and returns a report of findings against the chart standard. Use when asked to audit, review, analyse, assess or understand a chart, to run a quality or security review, or to list what must be fixed before bringing a chart into compliance. Works for charts of operator resources (CRDs) deployed by Argo CD as well as application charts.
argument-hint: <chart path> [values files]
---

# Chart review

Read-only: you modify and create no file. The report is returned in your reply.

If the chart path is not given, ask for it. One chart at a time.

## 1. Load the references

Read, in this order:

- [method.md](../_shared/references/method.md) — working rules, language,
  scenarios, rendering;
- [standard.md](../_shared/references/standard.md) — the rules.

## 2. Read the whole chart

`Chart.yaml`, `values.yaml`, `values.schema.json`, everything in `templates/`
(including `_helpers.tpl` and `NOTES.txt`), `README.md`, `CHANGELOG.md`, `tests/`,
the subcharts in `charts/`. Conclude nothing before reading it all.

Note the "Accepted deviations" section of the README: what is listed there is not
a finding.

If the chart renders pods (Deployment, StatefulSet, DaemonSet, Job, CronJob, Pod),
also read [standard-pods.md](../_shared/references/standard-pods.md).

## 3. Render

Establish the scenarios as described in `method.md`, then for each one:

```bash
helm template <release> <chart> --namespace <ns> -f <values…>
helm lint --strict <chart> -f <values…>
```

A failed render is a finding: VAL-07 for the `default` scenario, blocking for the
others. Record the exact error and carry on with the scenarios that render.

## 4. Run the available analyses

See [references/tools.md](references/tools.md): which tool to run depending on what
the chart contains, and which rule its results map to. Install nothing; list the
missing tools in the report.

## 5. Check the custom resources

For each `kind` outside the core Kubernetes API:

1. Find the operator version in the README prerequisites or `Chart.yaml`. If it is
   nowhere, that is an STR-06 finding, and you ask for it.
2. Compare the rendered resource with the schema: `oc explain <kind> --recursive`
   (or `kubectl explain`) if a cluster is reachable, otherwise the official
   documentation for that version. Record the source consulted.
3. Look for: required fields, immutable fields, effect of a deletion, deprecated
   `apiVersion`.

Anything no source confirms goes under "Not verified". Never write a field or a
behaviour from memory as if it were established.

## 6. Go through the standard rule by rule

**Every** rule, in order. For each: compliant, finding, accepted deviation, or not
applicable (with the reason).

A finding points to a file and a line. No general remark such as "labels could be
improved".

For each finding:

- the **class** of the fix (A, B, C), defined in the standard;
- the **severity** of the problem:

| Severity | Meaning |
|---|---|
| Blocking | Render or sync fails, possible service outage, exposed secret |
| Major | Effect on the cluster or on the values contract |
| Minor | Form, documentation, readability |

## 7. Return the report

Exactly this structure, written in the user's language:

```markdown
# Review — <chart> <version>

<Three sentences at most: overall state, main risk, estimated effort.>

## Rendering

| Scenario | Source | Render | Lint | Resources |
|---|---|---|---|---|

## Findings

| Rule | Severity | Finding | Location | Proposed fix | Class |
|---|---|---|---|---|---|

## Decisions to make

<Class C findings: the question, the options, the consequence of each.>

## Outside the standard

<Tool results no rule covers. Empty if none.>

## Not verified

<What the review could not establish and what it would take: missing real
scenarios, missing tools, sources not found.>

## Compliant or not applicable

<IDs only, on one or two lines.>
```

Sort findings by severity, then by rule.

End with the three fixes offering the best gain for the effort among classes A and
B, and suggest `helm-chart-maintenance` to apply them. If the user wants to keep
the report, offer to put it in a pull request or an issue; do not write a file on
your own initiative.
