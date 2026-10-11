# helm-skills

A repository of skills for AI assistants: audit, fix, create and test Helm charts
against a written standard. This is not a software project: Markdown, one helpers
file and a sync script.

## Where things are

| Path | Content |
|---|---|
| `claude/` | **Source of truth.** The four skills and `_shared/` |
| `claude/_shared/references/standard.md` | Numbered rules (STR, VAL, TPL, CRD, REL) |
| `claude/_shared/references/standard-pods.md` | WKL rules, for charts that render pods |
| `claude/_shared/references/method.md` | Standing rules, language, git, scenarios, render diff |
| `github-copilot/` | Generated copy, do not edit by hand |
| `scripts/sync-copilot.sh` | Regenerates `github-copilot/` from `claude/` |

## Rules for changes

1. Edit `claude/` only, then run `scripts/sync-copilot.sh`.
   `scripts/sync-copilot.sh --check` verifies the copy is up to date.
2. Rule IDs are stable: never renumber. A dropped rule is marked *retired*, a new
   one takes the next number.
3. A rule lives in the standard, a way of working in `method.md`, a procedure in
   the skill. Do not duplicate one in another: link to it.
4. The skills make the assistant write no tracking file: only files that belong
   to Helm, inside the chart.
5. Document a command only after running it. Otherwise state that it was not
   verified, as in `helm-chart-review/references/tools.md`.
6. Any content taken from another repository is credited in an "Origin" section
   of the file concerned.
7. Everything in this repository is written in English. The skills themselves
   tell the assistant to reply in the user's language.
8. No commit, push or release without an explicit request.

## Format of a skill

Constraints common to Claude Code and GitHub Copilot:

- one directory per skill, with a `SKILL.md`;
- the frontmatter starts on the first line;
- `name` identical to the directory name, lowercase with hyphens;
- `description`: what the skill does and when to use it, main use case first,
  1,024 characters at most — it is the only text read to decide whether the skill
  triggers;
- `SKILL.md` under 500 lines; detail goes into `references/`, linked from
  `SKILL.md` (a file that is not linked is never read);
- a reference to `_shared/` is written
  `` `${CLAUDE_SKILL_DIR}/../_shared/references/<file>.md` ``: this is the form
  the script knows how to convert for Copilot.

## Verifying a change

- Script: `scripts/sync-copilot.sh --check`.
- Templates and commands: replay them on a throwaway chart with
  `helm lint --strict`, `helm template` and `helm unittest`.
- Skill: copy it into the `.claude/skills/` of a charts repository and run it on a
  real chart. A skill does not load from this repository.
