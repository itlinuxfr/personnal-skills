# `helm test` pods

A test pod is created on the cluster by `helm test <release>` and succeeds if it
exits with code 0. It checks that the release **works**, whereas `helm unittest`
checks that the rendered output is correct.

## When to write one

Only if the chart is installed with `helm install` / `helm upgrade`.

Argo CD creates no Helm release and does not support test hooks: manifests
carrying them are ignored at sync time. On a chart deployed only by Argo CD, a
test pod is therefore neither created nor run.

## Shape

```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: {{ include "CHART.fullname" . }}-test-connection
  labels:
    {{- include "CHART.labels" . | nindent 4 }}
  annotations:
    helm.sh/hook: test
    helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: test
      image: "{{ .Values.tests.image.repository }}:{{ .Values.tests.image.tag }}"
      command: ["sh", "-c", "curl -fsS --max-time 10 http://{{ include \"CHART.fullname\" . }}:{{ .Values.service.port }}/healthz"]
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: [ALL]
      resources:
        requests: { cpu: 10m, memory: 16Mi }
        limits: { memory: 64Mi }
```

## Rules

- The annotation is `helm.sh/hook: test`. `test-success` is a legacy alias.
- The test pod is a workload: `standard-pods.md` applies (no fixed UID, fixed
  image tag, resources).
- The image comes from values, so it can point to an internal registry.
- A pod checks a single thing and ends quickly (`--max-time`), with no wait loop.
- No secret in the command: `secretKeyRef` if the test must authenticate.
- The test checks the application, not Kubernetes: no point in checking that a
  pod exists.

```bash
helm test <release> --namespace <ns> --logs
```

## Origin

Principles taken from `foxj77/claude-code-skills` (`helm-chart-testing`, MIT
license), with the annotation corrected and the security context added.
