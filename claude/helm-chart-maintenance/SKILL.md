---
name: helm-chart-maintenance
description: Modifies an existing Helm chart without breaking what is deployed, one change per commit, with a render diff at every step. Use when asked to fix, refactor, clean up or bring a chart into compliance, to apply the findings of a review, to bump its version, to deprecate or rename a values key, to update a dependency or to maintain its changelog. Not for creating a chart.
argument-hint: <chart path> [rules to fix, e.g. TPL-06 VAL-05]
compatibility: Requires helm, git, yq and a bash shell; the chart must be in a git repository. Optional: dyff for a YAML-aware diff, the helm unittest plugin.
---

# Chart maintenance

You are modifying a deployed chart. Each fix is isolated in a commit and checked
with a render diff. You never rewrite the chart.

## 1. Load the references

- `${CLAUDE_SKILL_DIR}/../_shared/references/method.md` — standing rules, language,
  git, scenarios, render diff commands;
- `${CLAUDE_SKILL_DIR}/../_shared/references/standard.md` — the rules;
- `${CLAUDE_SKILL_DIR}/../_shared/references/standard-pods.md` if the chart renders
  pods.

## 2. Preconditions

Stop and say so if one is missing:

- the chart is in a git repository and its working tree is clean
  (`git status -- <chart>`);
- you are on a working branch approved by the user (see `method.md`);
- at least one scenario renders without error. If only the `default` scenario
  fails, the first fix is VAL-07.

What needs fixing comes, in order: from the rules given as arguments, from the
review done earlier in the conversation, otherwise suggest running
`helm-chart-review` first.

## 3. Order the work

- Class A first, then class B.
- **Never class C** without an explicit request about that specific finding.
- The version bump comes last, alone (REL-03).

Announce the chosen order before starting.

## 4. Fix, one finding at a time

For each finding:

1. **Announce**: the rule, the files touched, the expected render diff — "none"
   (class A) or the lines that change and in which resources (class B).
2. **Modify**, for this finding only. Another problem noticed along the way is
   noted for the end, not fixed on the spot.
3. **Add the entry** to `CHANGELOG.md` under `[Unreleased]`, written for whoever
   deploys the chart and without rule ID (REL-02, format in
   [references/changes.md](references/changes.md)). No entry for a change users
   cannot notice.
4. **Verify**, for each scenario: render diff against `HEAD` and identity check
   (commands in `method.md`), then `helm lint --strict <chart>` and
   `helm unittest <chart>` if `tests/` exists.
5. **Decide**:

| Result | Action |
|---|---|
| The identity check shows a line | Undo (`git restore`), **stop**, say which resource would be deleted or recreated. |
| Render, lint or a test fails | Fix it once. If the failure persists, undo and stop with the error. |
| Class A and a non-empty diff | Check whether the difference has no effect (key order, quoting). Otherwise undo: the change is wrong or the finding was class B, say which. |
| Class B and a diff different from the announcement | Undo, explain the gap between expected and obtained, stop. |
| Diff matches the announcement | Commit, then next finding. |

6. **Commit**: `<chart>: <ID> <what changes>`, one finding per commit.

Paste the commands and their output in your reply. "The diff is empty" without the
command is worth nothing.

## 5. Special cases

See [references/changes.md](references/changes.md) before:

- choosing a version number;
- renaming, moving or removing a values key (class C);
- updating a dependency.

Documentation findings (STR-06, VAL-03) are fixed with the `helm-chart-docs`
skill: invoke it, or if it cannot be invoked from here, read its `SKILL.md` in
the sibling `helm-chart-docs` directory and follow it. Its commit counts as the
fix for those rules.

## 6. Wrap up

- Run the render diff again against the branch base: that is the cumulative
  effect.
- Give the pull request report described in `method.md`: fixes and commits,
  cumulative diff per scenario, scenarios not covered, remaining findings, pending
  class C decisions, problems noted along the way.
- Suggest the version bump according to REL-01, without applying it. If it is
  requested: a separate commit, where the `[Unreleased]` section of the changelog
  becomes `## [<version>] - <date>`; the expected diff is limited to the
  `helm.sh/chart` label.
- No push and no pull request without a request.
