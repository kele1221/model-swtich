# AGENTS.md

Project instructions for coding agents working in this fork.

## Repository Relationship

This repository is a fork/customization of `farion1231/cc-switch`.

- `origin`: `https://github.com/kele1221/model-swtich.git`
- `upstream`: `https://github.com/farion1231/cc-switch.git`
- `main`: tracks `upstream/main` and should stay close to the original project.
- `my-custom`: the long-lived branch for local/custom changes in this fork.

Do not put custom product work directly on `main` unless the user explicitly asks.

## Branch Discipline

Before editing, check:

```bash
git status --short --branch
git branch -vv
```

Expected default working branch for custom work:

```text
my-custom
```

Use `main` mainly to pull upstream updates. If you find yourself on `main` for a custom change, switch to `my-custom` first:

```bash
git switch my-custom
```

## Syncing Upstream

To bring in the original author's latest updates:

```bash
git fetch upstream --tags
git switch main
git merge --ff-only upstream/main
git push origin main

git switch my-custom
git rebase main
git push --force-with-lease
```

If `git rebase main` reports conflicts, resolve only the conflicted files, then continue:

```bash
git add <resolved-files>
git rebase --continue
```

If the conflict is unclear, stop and ask the user before choosing a behavior.

## Safety Rules

- Preserve user changes. Do not reset, checkout, or overwrite unrelated work.
- Do not run destructive git commands such as `git reset --hard`, broad `git checkout -- .`, or force pushes without understanding the current branch and user intent.
- Prefer small, focused commits on `my-custom`.
- Do not rewrite `main` history.
- When pushing rebased custom work, use `git push --force-with-lease`, not plain `--force`.

## Current Custom Baseline

The first protected custom commit created for this fork workflow is:

```text
4943ce41 WIP: preserve custom changes
```

Treat later custom work as building on top of that commit unless the user says otherwise.
