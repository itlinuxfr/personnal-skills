---
name: helm-chart-testing
description: Writes, extends and repairs the tests of a Helm chart with helm unittest, without a cluster. Use when asked to add tests to a chart, to assess what is covered, to understand why a test fails, or to protect a chart against regressions before or after bringing it into compliance. Also covers `helm test` pods for charts installed with Helm.
argument-hint: <chart path>
compatibility: Requires helm with the helm unittest plugin, git and a bash shell. No cluster needed.
---

# Chart tests

The tests check the chart's **rendered output** with `helm unittest`: they run
locally and in CI, without a cluster. They pin down what the chart promises —
names, protections, errors — so a future change does not break it silently.

You write in `<chart>/tests/` only. You do not modify templates: if a test reveals
a defect in the chart, you report it and suggest `helm-chart-maintenance`.

## 1. Load the references

- `${CLAUDE_SKILL_DIR}/../_shared/references/method.md` — standing rules, language,
  git;
- `${CLAUDE_SKILL_DIR}/../_shared/references/standard.md` — the rules cited in the
  tests.

## 2. Take stock

Check that the plugin is there (`helm plugin list`). If it is missing, say so and
give the install command; install nothing yourself.

Read the whole chart and the existing tests, then run:

```bash
helm unittest <chart>
```

A test that is already failing is dealt with first (section 6).

## 3. List what must be tested

Go through each template and note:

| To cover | What the test checks |
|---|---|
| Each branch (`if`, `with`, `range`) | The number of documents rendered, enabled and disabled |
| The default render | Succeeds, or fails with the expected message (VAL-07) |
| The name and namespace of each resource | Their exact value: it is the identity, hence a contract (TPL-02, TPL-03) |
| Each `required` and `fail` | The failure, with a message naming the key (TPL-07) |
| Each schema constraint | Wrong type, unknown key, empty list (VAL-05) |
| Protections | Deletion and sync annotations (CRD-04, CRD-07) |
| Labels | Standard labels present (TPL-01); selector unchanged (WKL-08) |
| Tricky values | Numeric string (`"2024"`), boolean as a string, IPv6, single-item list (TPL-06) |
| The README's accepted deviations | What is done instead of the rule |

Do not test Helm or Kubernetes: whether a valid YAML label is accepted by the API
is not the chart's business.

Give this list before writing, marking what is already covered.

## 4. Write

One suite per template: `tests/<lowercase kind>_test.yaml`. Verified syntax and
assertions in [references/unittest.md](references/unittest.md).

- One test = one promise, named with a sentence: `it: fails if a zone has no IP`.
  The rule ID goes in the name when there is one.
- Realistic values, close to the deployed scenarios.
- Explicit assertions on what matters. A snapshot (`matchSnapshot`) of the whole
  resource is to be avoided: it fails on every change and ends up being
  regenerated without being read.
- `tests/` is listed in `.helmignore`: tests do not go into the package.

## 5. Check that the tests protect

```bash
helm unittest <chart>
```

A test that has never failed proves nothing. For identity and protection tests,
deliberately break the template (remove the annotation, change the name), observe
the failure, then restore with `git restore <file>`. Paste both outputs in your
reply.

## 6. Diagnose a failing test

Work out which side is wrong before touching anything:

| Observation | Conclusion |
|---|---|
| The actual render (`helm template` with the same values) is correct | The test is wrong or outdated: fix the test |
| The actual render is wrong | The chart regressed: do not touch the test, report it |
| `failedTemplate` fails because the render succeeds | A protection (`required`, schema) disappeared: regression |
| Path error (`path`) | The wrong document is targeted: see `documentIndex` and `documentSelector` |

Never modify a test for the sole purpose of making it pass.

## 7. Wrap up

- Tests do not change the rendered output: class A, patch version (REL-01).
- An entry in `CHANGELOG.md` under `[Unreleased]`, in the Keep a Changelog format
  (REL-02).
- On the approved working branch: one commit `<chart>: tests <what is covered>`.
- Summarise: what is covered, what is not and why, chart defects revealed by the
  tests.

## `helm test` pods

Argo CD does not run Helm's test hooks: they are ignored at sync time. For a chart
deployed by Argo CD these pods therefore never run; do not write any.

For a chart that is also installed with `helm install`, see
[references/helm-test.md](references/helm-test.md).
