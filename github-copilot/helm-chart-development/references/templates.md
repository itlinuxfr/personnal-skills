# File templates

Starting points to adapt. `CHART` stands for the chart name.

## Chart.yaml

```yaml
apiVersion: v2
name: CHART
description: <one sentence: what the chart configures>
type: application
version: 0.1.0
# appVersion: version of the targeted operator or component. Remove it if it has
# no meaning (STR-02).
appVersion: "<x.y.z>"
kubeVersion: ">=1.27.0-0"
maintainers:
  - name: <team>
```

The `-0` suffix of `kubeVersion` accepts distribution versions (`v1.31.4+k3s1`,
OpenShift versions), which Helm treats as pre-releases.

## values.yaml

One `# --` comment per key (VAL-03): this is the format read by `helm-docs`, so
the README table can later be generated.

```yaml
# -- Overrides the chart name in resource names.
nameOverride: ""
# -- Overrides the full name of resources.
fullnameOverride: ""

backend:
  # -- Creates the resource. Disabled by default: rendering without values succeeds (VAL-07).
  enabled: false
  # -- Server address. Required when `backend.enabled` is true.
  server: ""
  # -- Exported paths, at least one.
  paths: []
```

## values.schema.json

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "global": { "type": "object" },
    "nameOverride": { "type": "string" },
    "fullnameOverride": { "type": "string" },
    "backend": {
      "type": "object",
      "additionalProperties": false,
      "required": ["enabled"],
      "properties": {
        "enabled": { "type": "boolean" },
        "server": { "type": "string" },
        "paths": { "type": "array", "items": { "type": "string", "minLength": 1 } }
      },
      "if": { "properties": { "enabled": { "const": true } } },
      "then": {
        "required": ["server", "paths"],
        "properties": {
          "server": { "minLength": 1 },
          "paths": { "minItems": 1 }
        }
      }
    }
  }
}
```

- `additionalProperties: false` rejects typos in values.
- `global` must stay declared: Helm adds it when the chart is used as a
  dependency, and the schema would reject it.
- `if` / `then` makes fields required only when the resource is enabled, without
  breaking the default render.

## Custom resource template

```yaml
{{- if .Values.backend.enabled }}
apiVersion: <group>/<version>
kind: <Kind>
metadata:
  name: {{ include "CHART.fullname" . }}
  labels:
    {{- include "CHART.labels" . | nindent 4 }}
  annotations:
    # CRD-04: the CRD may be missing at the first dry-run.
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
spec:
  server: {{ required "backend.server is required when backend.enabled is true" .Values.backend.server | quote }}
  paths:
    {{- toYaml .Values.backend.paths | nindent 4 }}
{{- end }}
```

Resource whose deletion cuts a service (CRD-07):

```yaml
  annotations:
    argocd.argoproj.io/sync-options: Prune=false
    helm.sh/resource-policy: keep
```

Several sync options are comma-separated within the same annotation.

## Workload fragment

To be used with `standard-pods.md`.

```yaml
spec:
  selector:
    matchLabels:
      {{- include "CHART.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "CHART.labels" . | nindent 8 }}
    spec:
      serviceAccountName: {{ include "CHART.fullname" . }}
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
        {{- with .Values.podSecurityContext }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: [ALL]
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
```

`podSecurityContext` defaults to `{}`: neither `runAsUser` nor `fsGroup` is set,
OpenShift assigns them (WKL-02).

## README.md

```markdown
# CHART

<Two or three sentences: what the chart configures, for whom, and what happens on
the cluster once it is synced.>

## Prerequisites

| Component | Version | Note |
|---|---|---|
| <operator> | <x.y> | CRD `<group>/<version>` `<Kind>` provided by the operator |

## Resources produced

| apiVersion / kind | Scope | Name | Enabled by |
|---|---|---|---|

## Values

| Key | Type | Default | Description |
|---|---|---|---|

## Example

<A realistic values file, and the Argo CD Application that carries it.>

## Accepted deviations

| Rule | What is done | Reason |
|---|---|---|
| TPL-02 | Fixed name `default` | Imposed by the operator |

## Good to know

<Immutable fields, effect of a deletion, operator-related pitfalls.>
```

## .helmignore

```
.git/
.gitignore
.DS_Store
.vscode/
.idea/
*.swp
*.bak
*.tmp
*.orig
*~
tests/
```

`tests/` is excluded from the package: the `helm unittest` suites stay in the
repository.

## Origin

Helpers and schema structure adapted from `foxj77/claude-code-skills`
(`helm-chart-development`, MIT license).
