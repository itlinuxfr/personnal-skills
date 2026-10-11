# helm-skills

Five skills for AI coding assistants to audit, fix, create and test Helm charts
the same way everywhere, against a written standard. Designed for charts deployed
by Argo CD on OpenShift: operator resources (CRDs) as well as application charts.

| Skill | Use | Modifies the chart? |
|---|---|---|
| `helm-chart-review` | Audit a chart and list its findings against the standard | No |
| `helm-chart-maintenance` | Fix an existing chart, one finding per commit | Yes |
| `helm-chart-development` | Create a chart that is compliant from version 0.1.0 | Creates the chart |
| `helm-chart-testing` | Write and repair `helm unittest` tests | `tests/` only |
| `helm-chart-docs` | Generate or update the README with `helm-docs`, keeping the chart's own layout | README, its template, values comments |

## Principles

- **A single standard**, `_shared/references/standard.md`: numbered rules
  (`TPL-02`, `CRD-07`…). Every finding and every fix refers to it.
- **No tracking files.** The skills only write files that belong to Helm, inside
  the chart. The audit report is in the conversation, work in progress is on a git
  branch, exceptions are in the chart's `README.md` ("Accepted deviations").
- **A render diff for every fix**: `helm template` before and after, compared. A
  renamed or deleted resource stops everything. This check replaces neither the
  pull request review nor a test on a cluster.

Each fix carries a risk class:

| Class | Meaning | Who decides |
|---|---|---|
| A | The rendered output does not change | The assistant |
| B | Rendered content changes, resource identity does not | The assistant, with the diff shown, reviewed in the pull request |
| C | Touches values keys or the identity of a resource | You, explicitly |

The assistant replies in your language; what it writes into a chart follows the
language that chart already uses.

## Installation

Copy the content of your assistant's directory to the root of your charts
repository.

| Assistant | Source | Destination |
|---|---|---|
| Claude Code | `claude/` | `.claude/skills/` |
| GitHub Copilot (VS Code) | `github-copilot/` | `.github/skills/` |

```bash
mkdir -p .claude/skills && cp -r <helm-skills>/claude/. .claude/skills/
# or
mkdir -p .github/skills && cp -r <helm-skills>/github-copilot/. .github/skills/
```

The `_shared/` directory must be copied along with the skills: they read the
standard from it.

Both directories have the same content. Only the way files in `_shared/` are
referenced differs: a Claude Code variable on one side, a relative link on the
other. `claude/` is the source: `github-copilot/` is regenerated with
`scripts/sync-copilot.sh`.

## Requirements

- The chart is in a git repository.
- `helm`, `git`, `yq` and a bash shell.
- The `helm unittest` plugin for tests, `helm-docs` for documentation.
- Optional, used when installed: `dyff`, `pluto`, `kubeconform`, `trivy`,
  `kubescape`, `polaris`, `oc`.

## Usage

```
/helm-chart-review charts/openshift-egressips
/helm-chart-maintenance charts/openshift-egressips TPL-06 VAL-05
/helm-chart-development trident-backend: declare one Trident NFS backend per cluster
/helm-chart-testing charts/openshift-egressips
```

Usual flow: a review, then maintenance on a dedicated branch, then a pull request
whose description reuses the report offered at the end of the work.

## Content

```
AGENTS.md                    contribution rules, read by assistants
CLAUDE.md                    pointer to AGENTS.md for Claude Code
scripts/sync-copilot.sh      regenerates github-copilot/ from claude/

claude/  and  github-copilot/
├── _shared/references/
│   ├── standard.md          rules STR, VAL, TPL, CRD, REL
│   ├── standard-pods.md     rules WKL, for charts that render pods
│   └── method.md            standing rules, language, git, scenarios, render diff
├── helm-chart-review/
├── helm-chart-maintenance/
├── helm-chart-development/
├── helm-chart-testing/
└── helm-chart-docs/
```

To change a rule, edit the standard without renumbering the others. To change a
way of working, edit `method.md` or the skill concerned. Contribution rules are in
`AGENTS.md`.

## Status

Early version. The commands and file templates in the skills were exercised with
Helm 4.2; the skills themselves have not yet been run on a fleet of real charts.
The Copilot variant is untested.

## Limits

- The assistant may skip a step or misclassify a finding. The guarantee rests on
  the command outputs it pastes: read them.
- The render diff is only as good as the values files it is given. A cluster
  missing from the scenarios is not covered.

## Origin

The split into skills, the analysis tools, the pod rules and several
templates are adapted from
[foxj77/claude-code-skills](https://github.com/foxj77/claude-code-skills) (MIT
license). The files concerned say so in an "Origin" section.
