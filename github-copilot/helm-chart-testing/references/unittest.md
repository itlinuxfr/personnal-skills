# helm unittest — cheat sheet

Syntax verified with Helm 4.2 and the unittest plugin 1.2. For an assertion that
is not listed here, check the plugin documentation
(`https://github.com/helm-unittest/helm-unittest/blob/main/DOCUMENT.md`) rather
than guessing.

```bash
helm plugin list                 # the "unittest" plugin must be listed
helm unittest <chart>            # runs tests/*_test.yaml
helm unittest -f 'tests/egressip_test.yaml' <chart>
```

## Structure of a suite

```yaml
suite: EgressIP
templates:
  - templates/egressip.yaml
release:                          # optional, applies to the whole suite
  name: egressips
  namespace: openshift-config
tests:
  - it: renders one EgressIP per zone
    set:                          # values for this test
      egressIP:
        enabled: true
        prefix: prod
        zones:
          - name: zone-a
            egressIPS: ["10.0.100.10"]
    asserts:
      - hasDocuments:
          count: 1
      - equal:
          path: metadata.name
          value: egress-prod-zone-a
```

Paths in `templates:` are relative to the chart, paths in `values:` to the test
file.

## Providing values

```yaml
    set:
      egressIP.enabled: true          # dotted notation
      egressIP.zones[0].name: zone-a

    values:
      - values/prod.yaml              # file, relative to the test file
```

Keep test values files in `tests/values/`. Never copy a real cluster file there:
it may contain sensitive data (VAL-06).

## Targeting the right document

A template that loops renders several documents.

```yaml
    asserts:
      - equal:
          path: metadata.name
          value: egress-prod-zone-b
        documentIndex: 1              # by position

    documentSelector:                 # by content, for the whole test
      path: metadata.name
      value: egress-prod-zone-b
```

Prefer `documentSelector`: it does not depend on render order.

## Assertions

| Assertion | Use |
|---|---|
| `hasDocuments: {count: n}` | Number of documents rendered; `0` for a disabled resource |
| `isKind: {of: EgressIP}` / `isAPIVersion: {of: k8s.ovn.org/v1}` | Resource type |
| `equal: {path, value}` | Exact value; works for a whole list or object |
| `matchRegex: {path, pattern}` | Variable value, such as `helm.sh/chart` which contains the version |
| `exists: {path}` / `notExists: {path}` | Presence or absence of a field |
| `contains: {path, content}` | One item in a list |
| `lengthEqual: {path, count}` | Size of a list |
| `isSubset: {path, content}` | Some keys among others, for example a few labels |
| `failedTemplate: {}` | The render fails, whatever the reason |
| `failedTemplate: {errorPattern: "prefix"}` | The render fails with a message containing this pattern |

A key containing a dot or a slash is written in brackets:

```yaml
      - equal:
          path: metadata.annotations["argocd.argoproj.io/sync-options"]
          value: Prune=false
```

## Testing a failure

Always with `errorPattern`: without it, the test also passes if the render fails
for another reason.

```yaml
  - it: fails if the prefix is empty (TPL-07)
    set:
      egressIP:
        enabled: true
        prefix: ""
        zones:
          - name: zone-a
            egressIPS: ["10.0.100.10"]
    asserts:
      - failedTemplate:
          errorPattern: "prefix"
```

The schema is checked before the templates: if a value violates both, the schema
message is the one returned (`at '/egressIP/prefix': minLength…`). The pattern
must fit both, hence the key name rather than a sentence.

## Snapshots

`matchSnapshot` writes the render into `tests/__snapshot__/` and compares on later
runs. Keep it for a specific block (`path: spec`), never the whole resource.
Regenerate with `helm unittest -u <chart>` only after reading the diff.
