# git-alias

A collection of Git subcommands that streamline a commit-focused, stacked-branch workflow. Each script lives in `bin/` and is invoked as `git <name>`.

## Commands

| Command   | Description                                                                                                                                                     |
| --------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `git cmt` | Smart commit assistant — commit to the current branch, a new branch (from the default branch), or a stacked branch, then optionally push and create a draft PR. |
| `git amd` | Amend any commit — creates a fixup commit and immediately autosquash-rebases it into the target (defaults to HEAD).                                             |
| `git fix` | Create a `--fixup` commit for a given ref (for manual rebase later).                                                                                            |
| `git rb`  | Fetch and interactive rebase onto the remote default branch with autosquash.                                                                                    |
| `git fp`  | Force push with lease (`--force-with-lease`).                                                                                                                   |

## Install

```bash
./install.sh            # symlinks into ~/.local/bin by default
./install.sh /usr/local/bin   # or pick a different target
```

The installer also:

- Sets `rebase.autoSquash=true` and `rebase.updateRefs=true` globally.
- Registers global git aliases so `git amd`, `git cmt`, etc. work everywhere.

Make sure the target directory is on your `PATH`.

## Usage examples

```bash
# Smart commit — choose where to land your changes
git cmt -m "add login page"

# Stage everything and commit to the current branch
git cmt -a -m "quick fix"

# Amend the last commit with any unstaged changes
git amd

# Amend a specific older commit
git amd abc1234

# Create a fixup commit for later squashing
git fix abc1234

# Rebase onto latest origin default branch (main or master)
git rb

# Safe force push
git fp
```

## `git cmt` workflow

When you run `git cmt`, it shows your working tree status, asks for a commit message (unless `-m` is provided), then prompts:

```text
Commit to:
  [t] This branch (current-branch)
  [n] New branch (from main)
  [s] Stacked branch (from this branch)
```

Choosing **n** or **s** will:

1. Commit on the current branch temporarily.
2. Create a new branch from the chosen base.
3. Cherry-pick the commit onto the new branch.
4. Push and optionally open a draft PR via `gh`.
5. Return you to the original branch with your working tree intact.

If anything goes wrong, changes are rolled back automatically.

## Requirements

- Bash
- Git
- [`gh` CLI](https://cli.github.com/) (for PR creation in `git cmt`)
- A `git create <slug> [<base>]` command for branch creation (used by `git cmt`)

## Tests

Tests use [Bats](https://github.com/bats-core/bats-core):

```bash
bats test/
```
