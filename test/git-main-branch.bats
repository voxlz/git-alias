#!/usr/bin/env bats
# Tests verifying all commands work with "main" as the default branch

load test_helper

setup() {
  setup_mocks
  setup_test_repo_main
}

teardown() {
  teardown_test_repo
}

# ─── git-cmt with main ───

@test "[main] cmt [t] commits to current branch" {
  echo "change" >> file.txt
  git add file.txt

  printf 't\n' | git-cmt -m "direct commit"

  assert_on_branch main
  assert_commit_message "direct commit"
}

@test "[main] cmt [n] creates branch from main (not master)" {
  echo "change" >> file.txt
  git add file.txt

  printf 'n\nn\n' | git-cmt -m "my feature"

  assert_branch_exists torbenn/my-feature
  assert_on_branch main

  # New branch should be based on main
  git checkout torbenn/my-feature
  assert_commit_message "my feature"
}

@test "[main] cmt [n] returns to main" {
  echo "change" >> file.txt
  git add file.txt

  printf 'n\nn\n' | git-cmt -m "my feature"

  assert_on_branch main
}

@test "[main] cmt [n] pushes to remote" {
  echo "change" >> file.txt
  git add file.txt

  printf 'n\nn\n' | git-cmt -m "my feature"

  git ls-remote --heads origin torbenn/my-feature | grep -q torbenn/my-feature
}

@test "[main] cmt [n] restores unstaged changes" {
  echo "staged" >> file.txt
  git add file.txt
  echo "wip" > unstaged.txt

  printf 'n\nn\n' | git-cmt -m "my feature"

  assert_on_branch main
  assert_file_exists unstaged.txt
  assert_stash_empty
}

@test "[main] cmt [s] stacked branch works from main" {
  echo "change" >> file.txt
  git add file.txt

  printf 's\nn\n' | git-cmt -m "stacked from main"

  assert_on_branch main
  assert_branch_exists torbenn/stacked-from-main
}

@test "[main] cmt [n] blocks when file doesn't exist on main" {
  # Create a feature branch with a file that doesn't exist on main
  git checkout -b feature
  echo "feature only" > feature-only.txt
  git add feature-only.txt
  git commit -q -m "add feature file"

  # Modify the feature-only file
  echo "modified" >> feature-only.txt
  git add feature-only.txt

  # Trying [n] (new from main) should fail: feature-only.txt doesn't exist on main
  run bash -c 'printf "n\n" | git-cmt -m "test"'

  [ "$status" -ne 0 ]
  [[ "$output" == *"Cannot move to new branch"* ]]
}

# ─── git-rb with main ───

@test "[main] rb rebases onto origin/main" {
  git checkout -b feature

  echo "feature work" >> file.txt
  git add file.txt
  git commit -q -m "feature commit"

  # Advance main on remote
  local tmp
  tmp=$(mktemp -d)
  git clone -q -b main "$REMOTE_DIR" "$tmp/clone"
  cd "$tmp/clone"
  git config user.email "other@test.com"
  git config user.name "Other"
  echo "remote" > remote.txt
  git add remote.txt
  git commit -q -m "remote advance"
  git push -q origin main
  cd "$TEST_DIR"
  rm -rf "$tmp"

  GIT_SEQUENCE_EDITOR=: git-rb

  assert_commit_message "feature commit"
  git log --oneline | grep -q "remote advance"
}

@test "[main] rb autosquashes fixup commits" {
  echo "base" >> file.txt
  git add file.txt
  git commit -q -m "base change"
  git push -q origin main

  git checkout -b feature

  echo "feature" >> file.txt
  git add file.txt
  git commit -q -m "feature work"

  echo "fix" >> file.txt
  git add file.txt
  git commit -q --fixup HEAD

  GIT_SEQUENCE_EDITOR=: git-rb

  # fixup should be squashed — only "feature work" remains on top
  assert_commit_message "feature work"
}

# ─── git-amd with main ───

@test "[main] amd amends HEAD" {
  echo "original" >> file.txt
  git add file.txt
  git commit -q -m "my commit"

  echo "fix" >> file.txt
  git add file.txt

  git-amd

  assert_commit_message "my commit"
  assert_file_contains file.txt "fix"
}

# ─── git-fp with main ───

@test "[main] fp force pushes current branch" {
  echo "change" >> file.txt
  git add file.txt
  git commit -q -m "local commit"

  echo "amended" >> file.txt
  git add file.txt
  git commit -q --amend --no-edit

  git-fp

  local remote_sha local_sha
  remote_sha=$(git ls-remote --heads origin main | awk '{print $1}')
  local_sha=$(git rev-parse HEAD)
  [ "$remote_sha" = "$local_sha" ]
}
