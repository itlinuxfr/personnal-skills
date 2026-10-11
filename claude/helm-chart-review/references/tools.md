# Analysis tools

Run what is installed (`command -v <tool>`), install nothing. Each result is mapped
to a rule of the standard; otherwise it goes under "Outside the standard".

Tools marked "pods" have nothing to say about a chart that only renders custom
resources: do not run them in that case.

In the commands, `<render>` stands for
`helm template <release> <chart> --namespace <ns> -f <values…>`.

## Always

| Tool | Command | What it finds | Rule |
|---|---|---|---|
| helm lint | `helm lint --strict <chart> -f <values…>` | Structure errors, SemVer, values schema | STR-01, VAL-05, VAL-07 |
| helm unittest | `helm unittest <chart>` (if `tests/` exists) | Failing chart tests | — (blocking) |

## APIs and schemas

| Tool | Command | What it finds | Rule |
|---|---|---|---|
| pluto | `<render> \| pluto detect -` | Deprecated or removed `apiVersion` | CRD-02 |
| kubeconform | `<render> \| kubeconform -summary -ignore-missing-schemas -` | Resource not conforming to the core API schema; CRDs are skipped without their schema | CRD-03 |
| oc / kubectl | `oc explain <kind> --recursive` | Actual CRD schema on the connected cluster | CRD-03 |

`oc apply --dry-run=server -f -` validates the render against the cluster, CRDs
included. It contacts the API of the connected cluster: run it only if the user
asks, and say which cluster (`oc whoami --show-server`).

## Security and good practice (pods)

| Tool | Command | What it finds | Rule |
|---|---|---|---|
| trivy | `trivy config <chart>` | Security context, privileges, plaintext secrets | WKL-01, WKL-03, WKL-09 |
| kubescape | `<render> \| kubescape scan framework nsa -` | Same, NSA framework | WKL-01, WKL-03, WKL-07 |
| polaris | `<render> \| polaris audit --audit-path -` | Resources, probes, image tag | WKL-04, WKL-05, WKL-06 |

These tools often recommend a fixed `runAsUser`: on OpenShift that contradicts
WKL-02, do not report it.

## Reliability of the commands

`helm lint` and `helm unittest` were verified (Helm 4.2, unittest plugin 1.2). The
`pluto`, `kubeconform`, `trivy`, `kubescape` and `polaris` commands are taken from
`foxj77/claude-code-skills` (MIT license) without having been executed: if one
fails, check `<tool> --help` rather than retrying.
