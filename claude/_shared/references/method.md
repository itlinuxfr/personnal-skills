# Shared working method

Rules followed by every `helm-chart-*` skill. The substantive rules are in
[standard.md](standard.md).

## Standing rules

1. Never rename, move or remove a `values.yaml` key without an explicit request:
   it is the contract with the chart's users (VAL-01).
2. Never change the `apiVersion`, `kind`, `metadata.name` or `metadata.namespace`
   of a rendered resource without an explicit request: Argo CD would delete then
   recreate the resource.
3. Never invent a CRD field. Accepted sources are the CRD schema
   (`oc explain <kind> --recursive` or `kubectl explain`), or the official
   documentation of the version stated in the README prerequisites. Anything no
   source confirms is reported as "not verified" and is not used in a template.
4. Targeted changes: do not rewrite a whole file, do not restructure anything
   beyond the rule being worked on.
5. No push, no pull request and no version bump without an explicit request.

## Language

- Reply and write reports in the language the user writes in.
- Anything written into the chart (README, changelog, comments, error messages,
  commit messages) follows the language already used in that chart.
- Rule IDs, class letters and commands are never translated.

## No tracking files

The skills create no file outside the chart, and inside the chart only files that
belong to Helm (`Chart.yaml`, `values.yaml`, `values.schema.json`, `templates/`,
`tests/`, `README.md`, `CHANGELOG.md`, `.helmignore`).

| Information | Where it lives |
|---|---|
| Findings | The assistant's reply; on request, the pull request description |
| Fixed findings | Git history: one commit per rule fixed |
| Accepted deviations | The chart's `README.md` |
| Renders used for comparison | A temporary directory, removed at the end of the step |

A finding is identified by its rule and location (`TPL-06` in
`templates/egressip.yaml:11`), not by a number.

## Git

The chart must be in a git repository. If it is not, say so and offer `git init`.

- Work on a dedicated branch, never on the default branch. Suggest a name
  (`chart/<chart>-compliance`) and wait for approval before creating it.
- Once the branch is approved: **one commit per rule fixed**, message
  `<chart>: <rule ID> <what changes>`.
- Undoing a fix = `git revert` or `git restore` of that fix alone.

## Render scenarios

A scenario is a combination (release, namespace, values files in order) that is
actually deployed. Look for them in this order:

1. the Argo CD `Application` and `ApplicationSet` resources in the repository that
   point to the chart (`releaseName`, `destination.namespace`, `valueFiles`);
2. what the user states;
3. failing that, the README examples, **saying they are illustrative**.

Values to use when the `Application` does not set them:

- **Release**: without `releaseName`, Argo CD uses the `Application` name
  (`metadata.name`). Pass that name to `helm template`, otherwise names derived
  from `.Release.Name` are wrong.
- **Namespace**: without `destination.namespace`, omit `--namespace`.

A namespace hardcoded in a template gets in the way of nothing: it is rendered as
is, whatever `--namespace` says. It is compliant if it is imposed and listed in
the accepted deviations (TPL-03). A resource with no `metadata.namespace` in the
output receives `destination.namespace` at sync time.

Always add a `default` scenario, with no values file.

Every conclusion drawn from a render cites the scenarios used. Without a real
scenario, say that the diff does not cover the deployed clusters.

## Render diff

It compares what Argo CD would apply before and after. It is a fast check while
working; validation remains the pull request review and a test on a cluster.

The reference is a git commit, nothing is stored. `HEAD` to see the effect of the
fix in progress, the branch base to see the cumulative effect.

```bash
ref=HEAD                                  # or: git merge-base HEAD <default branch>
tmp=$(mktemp -d)
git archive "$ref" <chart> | tar -x -C "$tmp"
helm template <release> "$tmp/<chart>" --namespace <ns> -f <values…> > "$tmp/before.yaml"
helm template <release> <chart>        --namespace <ns> -f <values…> > "$tmp/after.yaml"
dyff between "$tmp/before.yaml" "$tmp/after.yaml" 2>/dev/null \
  || diff -u "$tmp/before.yaml" "$tmp/after.yaml"
```

`dyff` compares YAML rather than text; without it, `diff -u` also reports changes
that have no effect (key order, quoting): say so when that is the case.

Identity check, on the same files:

```bash
id='[.apiVersion, .kind, .metadata.namespace // "", .metadata.name] | join(" ")'
diff <(yq -r "$id" "$tmp/before.yaml" | sort) <(yq -r "$id" "$tmp/after.yaml" | sort)
rm -rf "$tmp"
```

A line in this second diff = a resource created, deleted or recreated. **Stop**,
undo the fix, explain. Continue only on request.

If the chart has dependencies that are not committed under `charts/`, run
`helm dependency build` in both copies before rendering.

Paste the command and its output in the reply (truncate a long diff, keeping the
beginning and the line count).

## Pull request report

At the end of the work, offer a ready-to-paste text: rules fixed (with the
commit), cumulative render diff per scenario, scenarios not covered, points not
verified, remaining findings and pending class C decisions.
