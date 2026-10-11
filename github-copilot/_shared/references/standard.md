# Chart standard

Single reference for the `helm-chart-*` skills. Every finding and every change
cites the ID of the rule it relates to (e.g. `TPL-02`). IDs are stable: never
renumber; a dropped rule is marked *retired*.

This file applies to every chart. If the chart renders pods (Deployment,
StatefulSet, DaemonSet, Job, CronJob, Pod), also read
[standard-pods.md](standard-pods.md).

## Fix classes

- **A** — the rendered output does not change (pure refactoring).
- **B** — rendered content changes, resource identity does not.
- **C** — touches the values contract or the identity of a resource: a human
  decision, never taken by the assistant.

When in doubt between two classes, pick the more cautious one.

## Accepted deviations

A rule may not apply to a chart for a good reason (name imposed by an operator,
singleton chart…). That choice is written **in the chart**, in an "Accepted
deviations" section of its `README.md` (or the equivalent title in the chart's
language): the rule, what is done instead, and why. An accepted deviation is not
a finding and is not reported again.

## STR — Structure

| ID | Rule | Why | Class |
|---|---|---|---|
| STR-01 | `Chart.yaml` uses `apiVersion: v2` with `description`, `type`, a SemVer `version`, `maintainers`, `kubeVersion`. | Metadata required by registries and shown in Argo CD. | A |
| STR-02 | `appVersion` is the version of the targeted operator or component; absent when it has no meaning. | Avoids a decorative `appVersion` nobody maintains. | A |
| STR-03 | Dependencies pinned to an exact version, `Chart.lock` committed. | Reproducible rendering. | B |
| STR-04 | One template file per resource type, named after the lowercase `kind`. | A resource is found without searching. | A |
| STR-05 | Named templates live in `_helpers.tpl` and are prefixed with the chart name. | Template names are global across a chart and its subcharts. | A |
| STR-06 | `README.md`: purpose of the chart, prerequisites (operator, version, expected CRDs), values table, accepted deviations. | A chart is unusable without its prerequisites; accepted deviations stop people from "fixing" them. | A |
| STR-07 | `.helmignore` present; no non-chart file in the package. | Clean package, no leak of local files. | A |

## VAL — Values

| ID | Rule | Why | Class |
|---|---|---|---|
| VAL-01 | Every existing key is a contract: no rename, move or removal without a transition alias and a major version. | Per-cluster values files depend on it. | C |
| VAL-02 | New keys are camelCase. | Helm convention. | — |
| VAL-03 | Every key in `values.yaml` has a comment describing its effect. | Serves as documentation and feeds the README. | A |
| VAL-04 | Every key read by a template is declared in `values.yaml`; no declared key is unused. | Removes ghost values and dead parameters. | A or C |
| VAL-05 | `values.schema.json` describes types and required fields. | A values mistake fails at render time, not on the cluster. | B |
| VAL-06 | No secret in versioned values. | — | C |
| VAL-07 | Rendering with default values alone succeeds, or fails with an explicit `required` message. | Lint and review are possible without a cluster file. | B |

## TPL — Templates

| ID | Rule | Why | Class |
|---|---|---|---|
| TPL-01 | Labels `app.kubernetes.io/name`, `instance`, `version`, `managed-by` and `helm.sh/chart` are set by a single helper. | Uniform selection and inventory. | B |
| TPL-02 | Resource names derive from a `fullname` helper, unless the name is imposed (accepted deviation). | Two installations of the chart do not collide. | C |
| TPL-03 | No hardcoded namespace, unless the namespace is imposed (accepted deviation). | Same. | C |
| TPL-04 | No `lookup`, no logic depending on `.Release.IsUpgrade` / `.Release.IsInstall`. No non-deterministic function (`now`, `uuidv4`, `randAlphaNum`…). | Argo CD renders with `helm template`: no cluster access, always an install; output that changes on every render keeps the application permanently out of sync. | B |
| TPL-05 | Any use of `.Capabilities` is justified (accepted deviation). | Its value depends on Argo CD's configuration, not on the cluster. | B |
| TPL-06 | YAML blocks are injected with `toYaml` + `nindent`; strings go through `quote`. | Avoids indentation and typing errors (`"true"`, `"1.10"`). | A |
| TPL-07 | Required values are checked with `required` or `fail`, with a message naming the key. | Readable error at render time. | B |
| TPL-08 | No logic duplicated across templates: factor it into a helper. | A fix is made in one place. | A |

## CRD — Custom resources

Not applicable if the chart only renders core Kubernetes API resources.

| ID | Rule | Why | Class |
|---|---|---|---|
| CRD-01 | The chart does not ship the CRDs of an operator it does not deploy. | The CRD lifecycle belongs to the operator. | C |
| CRD-02 | Every `apiVersion` used is served and not deprecated by the operator version stated in the README prerequisites. | Otherwise sync fails at the next operator upgrade. | B or C |
| CRD-03 | Every rendered custom resource conforms to its CRD schema. | The only check that understands these resources. | B |
| CRD-04 | If the CRD may be missing at sync time, ordering is handled explicitly (sync-wave, `SkipDryRunOnMissingResource=true`). | Otherwise Argo CD fails at dry-run. | B |
| CRD-05 | Cluster-scoped resources have a name unique per installation, or the chart is declared a "singleton" (accepted deviation). | Silent collision between two installations. | C |
| CRD-06 | Immutable fields are called out in the README and are not exposed as plain modifiable values. | A change would block sync or force a recreation. | C |
| CRD-07 | Deletion behaviour is explicit for resources whose disappearance cuts a service (`Prune=false`, `helm.sh/resource-policy: keep`, finalizers). | An accidental deletion of an EgressIP or IngressController is a network outage. | B |

## REL — Release

| ID | Rule | Why | Class |
|---|---|---|---|
| REL-01 | Identical output → patch. Rendered content changed or new key → minor. Values contract or identity changed → major. | The version announces the risk. | — |
| REL-02 | `CHANGELOG.md`: one line per change, with the rule ID. | Trace of the work done. | A |
| REL-03 | The version bump is the last step, isolated in its own commit. | It changes the `helm.sh/chart` label on every resource and would drown the other diffs. | B |
