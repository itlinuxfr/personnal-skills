# Pod security context reference

Canonical reference for pod and container security contexts in a chart, on
Kubernetes and on OpenShift. The rules are in [standard-pods.md](standard-pods.md)
(WKL-01 to WKL-03); this file shows what they look like and why OpenShift differs.

## Portable defaults

These settings are accepted both by the Kubernetes "restricted" Pod Security
Standard and by the OpenShift `restricted-v2` SCC. They are what a chart renders
when no value is given.

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
    # No runAsUser, runAsGroup or fsGroup here: see "User and group IDs".
  containers:
    - name: app
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
          # add: [NET_BIND_SERVICE]   only if really needed
      ports:
        - containerPort: 8080          # 1024 or above
```

## User and group IDs

This is where the two platforms part ways.

| Setting | Kubernetes (restricted) | OpenShift (`restricted-v2`) |
|---|---|---|
| `runAsUser` | Free, any non-root UID | `MustRunAsRange`: must fall in the range allocated to the namespace |
| `fsGroup` | Free | `MustRunAs`: must be the group allocated to the namespace |
| `supplementalGroups` | Free | `RunAsAny` |
| SELinux level | — | `MustRunAs`: taken from the namespace |

On OpenShift each namespace carries its own allocation:

```yaml
metadata:
  annotations:
    openshift.io/sa.scc.uid-range: 1000680000/10000
    openshift.io/sa.scc.supplemental-groups: 1000680000/10000
    openshift.io/sa.scc.mcs: s0:c26,c15
```

A pod that leaves `runAsUser` and `fsGroup` unset receives values from that range.
A pod that hardcodes `runAsUser: 1000` or `fsGroup: 1000` is outside it: no SCC
available to an ordinary service account validates the pod, and it is rejected.

So a chart exposes these fields as values and leaves them empty (WKL-02):

```yaml
# values.yaml
# -- Pod security context added to the defaults. Leave `runAsUser` and `fsGroup`
# unset on OpenShift: the platform assigns them from the namespace range.
podSecurityContext: {}
```

```yaml
# template
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
        {{- with .Values.podSecurityContext }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
```

On plain Kubernetes the user sets `podSecurityContext.runAsUser` in their values
when the image needs it.

## Running as an arbitrary UID

On OpenShift the container process runs with a UID the image never heard of, and
is always a member of the root group. Consequences for the chart:

- every path the process writes to is a volume (`emptyDir`, PVC), never a
  directory of the image — which `readOnlyRootFilesystem: true` enforces anyway;
- no command, init container or script assumes a user name or a fixed UID
  (`chown 1000`, `su app`);
- containers listen on ports 1024 and above; the Service maps the public port.

Whether the image itself tolerates an arbitrary UID (directories owned by the
root group and group-writable) is the image's business, not the chart's: if it
does not, that is a prerequisite to state in the README.

## OpenShift SCCs

| SCC | What it allows | Typical use |
|---|---|---|
| `restricted-v2` | Namespace-allocated UID, SELinux level and fsGroup; all capabilities dropped; no privilege escalation; volumes limited to configMap, downwardAPI, emptyDir, persistentVolumeClaim, projected, secret | Default for authenticated users: what a chart should fit in |
| `nonroot-v2` | Same, with any non-root UID | Image that needs one specific non-root UID |
| `anyuid` | Any UID and GID, including root | Image that must run as root |
| `hostnetwork-v2` | Host networking and host ports | Network components |
| `privileged` | Everything | Cluster administration only |

Recent versions also ship `restricted-v3` (as `restricted-v2`, with user
namespaces at pod level), intended as the default on new installations.

A workload does not obtain more rights by writing them in its pod spec: its
ServiceAccount must be allowed to use an SCC that permits them. When a chart
really needs one, it ships the grant and declares it as an accepted deviation
(WKL-03):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ include "CHART.fullname" . }}-scc
rules:
  - apiGroups: ["security.openshift.io"]
    resources: ["securitycontextconstraints"]
    resourceNames: ["nonroot-v2"]
    verbs: ["use"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ include "CHART.fullname" . }}-scc
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: {{ include "CHART.fullname" . }}-scc
subjects:
  - kind: ServiceAccount
    name: {{ include "CHART.fullname" . }}
    namespace: {{ .Release.Namespace }}
```

Project administrators cannot grant `use` on an SCC by default: whoever syncs the
chart needs that right, which is a prerequisite to state in the README.

To pin the SCC a pod is admitted with, rather than depend on which ones happen to
be available, set the annotation on the pod template:

```yaml
  template:
    metadata:
      annotations:
        openshift.io/required-scc: restricted-v2
```

## Namespace labels

On Kubernetes, the Pod Security Standard is enforced by labels on the namespace
(`pod-security.kubernetes.io/enforce: restricted`).

On OpenShift the `warn` and `audit` labels are synchronized automatically from
the SCCs usable in the namespace, and setting one by hand turns synchronization
off for that label. A chart therefore does not set `pod-security.kubernetes.io/*`
labels on an OpenShift namespace unless that is its purpose; the control is
`security.openshift.io/scc.podSecurityLabelSync` (`"true"` or `"false"`).

## Quick reference

| Setting | Level | Chart default | Kubernetes restricted | OpenShift `restricted-v2` |
|---|---|---|---|---|
| `runAsNonRoot` | pod, container | `true` | Required | Satisfied by the assigned UID |
| `runAsUser` | pod, container | unset | Optional | Must be in the namespace range |
| `fsGroup` | pod | unset | Optional | Must be the namespace group |
| `allowPrivilegeEscalation` | container | `false` | Required | Must be unset or `false` |
| `capabilities.drop` | container | `[ALL]` | Required | Required |
| `capabilities.add` | container | none | `NET_BIND_SERVICE` only | `NET_BIND_SERVICE` only |
| `seccompProfile.type` | pod, container | `RuntimeDefault` | Required | Defaulted to it |
| `readOnlyRootFilesystem` | container | `true` | Recommended | Recommended |
| `privileged` | container | absent | Forbidden | Forbidden |
| `hostNetwork`, `hostPID`, `hostIPC`, `hostPath` | pod | absent | Forbidden | Forbidden |

## Anti-patterns

```yaml
# Rejected on OpenShift, and meaningless elsewhere unless the image needs it
securityContext:
  runAsUser: 1000
  fsGroup: 1000

# Never by default
securityContext:
  privileged: true
  runAsUser: 0
  allowPrivilegeEscalation: true

hostNetwork: true
hostPID: true
hostIPC: true
volumes:
  - hostPath:
      path: /
```

Granting an SCC with `oc adm policy add-scc-to-user` outside the chart is also an
anti-pattern here: the grant is invisible in git and lost on a new cluster.

## Sources

OpenShift behaviour checked on 2026-10-11 against the OKD documentation (latest):

- `https://docs.okd.io/latest/authentication/managing-security-context-constraints.html`
- `https://docs.okd.io/latest/authentication/understanding-and-managing-pod-security-admission.html`
- `https://docs.okd.io/latest/openshift_images/create-images.html`

Check the documentation of your own version before relying on a detail: the set
of default SCCs changes between releases.

## Origin

Structure and Kubernetes content adapted from `foxj77/claude-code-skills`
(`_shared/references/pod-security-context.md`, MIT license). The fixed
`runAsUser: 1000` / `fsGroup: 1000` of the original is replaced by unset values,
and the OpenShift sections are added.
