# CLAUDE.md

Instructions for Claude Code when working in this fork.

This project is a customized fork of `farion1231/cc-switch`.

## Git Remotes and Branches

- `origin`: `https://github.com/kele1221/model-swtich.git`
- `upstream`: `https://github.com/farion1231/cc-switch.git`
- `main`: tracks `upstream/main`; keep it close to the original project.
- `my-custom`: long-lived branch for this fork's local changes.

Use `my-custom` for implementation work unless the user explicitly asks to work on another branch.

## Before Making Changes

Run:

```bash
git status --short --branch
git branch -vv
```

If on `main` and the task is a local customization, switch first:

```bash
git switch my-custom
```

Do not move or rewrite `main` except to fast-forward it from `upstream/main`.

## Upstream Update Workflow

Use this sequence to sync the original author's changes:

```bash
git fetch upstream --tags
git switch main
git merge --ff-only upstream/main
git push origin main

git switch my-custom
git rebase main
git push --force-with-lease
```

If conflicts occur during the rebase, resolve only the conflicted files and continue:

```bash
git add <resolved-files>
git rebase --continue
```

Ask the user before making non-obvious conflict-resolution decisions.

## Safety

- Preserve uncommitted and unrelated user changes.
- Do not use destructive git commands unless the user explicitly asks.
- Use focused commits on `my-custom`.
- Use `git push --force-with-lease` after rebasing a pushed custom branch.
- Never use plain `git push --force`.

## Custom Baseline

Current protected custom baseline:

```text
4943ce41 WIP: preserve custom changes
```
