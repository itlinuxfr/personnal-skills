# Chart standard — workloads

Complement to [standard.md](standard.md), to be read **only** if the chart renders
pods (Deployment, StatefulSet, DaemonSet, Job, CronJob, Pod). Not applicable to a
chart that only renders custom resources.

Classes A, B, C and "accepted deviations" are defined in `standard.md`.

For what WKL-01 to WKL-03 look like in a template, and for the OpenShift
specifics behind them (namespace UID ranges, SCCs), read
[pod-security-context.md](pod-security-context.md).

## WKL — Workloads

| ID | Rule | Why | Class |
|---|---|---|---|
| WKL-01 | Every container sets `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `runAsNonRoot: true` and `seccompProfile.type: RuntimeDefault`. `readOnlyRootFilesystem: true` is recommended. | Requirements of the "restricted" Pod Security Standards profile. | B |
| WKL-02 | `runAsUser`, `runAsGroup` and `fsGroup` are not set by default; they are exposed as values, empty. | On OpenShift, the `restricted-v2` SCC assigns the UID and the fsGroup from the namespace range: a fixed value (e.g. `1000`) gets the pod rejected. On plain Kubernetes the user sets them in their values when the image needs it. | B |
| WKL-03 | No `privileged: true`, `hostNetwork`, `hostPID`, `hostIPC` or `hostPath` volume, unless it is an accepted deviation. On OpenShift, a workload that needs more than `restricted-v2` ships the `Role` and `RoleBinding` granting its ServiceAccount the SCC, and declares it as an accepted deviation. | Host access; and a grant made outside the chart is invisible in git and lost on a new cluster. | C |
| WKL-04 | `resources.requests` (CPU and memory) and `resources.limits.memory` have a default value, tunable through values. | Predictable scheduling, no neighbour exhausting the node. | B |
| WKL-05 | The image has a fixed tag (never `latest`), defaulting to `appVersion`; a digest remains possible through values. | Reproducible rendering. | B |
| WKL-06 | Long-running containers have a `readinessProbe` and a `livenessProbe`, tunable through values. | Without them, traffic reaches a pod that is not ready. | B |
| WKL-07 | The workload has its own ServiceAccount, with `automountServiceAccountToken: false` unless really needed. RBAC uses no wildcard (`*`) and prefers `Role` over `ClusterRole`. | Least privilege. | B or C |
| WKL-08 | Selector labels (`spec.selector.matchLabels`) contain only `app.kubernetes.io/name` and `instance`, and never change. | The selector of a Deployment or StatefulSet is immutable: changing it forces a delete and recreate. | C |
| WKL-09 | No plaintext secret in `env[].value`, in a command or in a ConfigMap: reference it with `secretKeyRef` or a volume. | Complements VAL-06. | C |

## Caution when applying TPL-01

Adding the labels helper to an existing workload must only touch `metadata.labels`
and `spec.template.metadata.labels`. If it changes `spec.selector.matchLabels`, it
is a class C fix (WKL-08).

## Origin

Rules adapted from `foxj77/claude-code-skills`
(`_shared/references/pod-security-context.md`,
`helm-chart-review/references/security-checklist.md`, MIT license), corrected for
OpenShift (WKL-02).
