#!/usr/bin/env bats
# Tests for git-cmt: stacked branch ([s] option)

load test_helper

setup() {
  setup_mocks
  setup_test_repo
}

teardown() {
  teardown_test_repo
}

# ─── [s] Stacked branch (from current branch) ───

@test "[s] creates branch from current branch" {
  # Start on a feature branch
  git checkout -b feature/base
  git push -q -u origin feature/base

  echo "change" >> file.txt
  git add file.txt

  printf 's\nn\n' | git-cmt -m "stacked change"

  assert_branch_exists torbenn/stacked-change
  # Verify it branched from feature/base, not master
  git checkout torbenn/stacked-change
  assert_commit_message "stacked change"
}

@test "[s] returns to original branch" {
  git checkout -b feature/base
  git push -q -u origin feature/base

  echo "change" >> file.txt
  git add file.txt

  printf 's\nn\n' | git-cmt -m "stacked change"

  assert_on_branch feature/base
}

@test "[s] does NOT check for files existing on master" {
  # This is the key difference from [n]: stacked branches don't validate
  # against master because they branch from the current branch where
  # the files already exist.
  git checkout -b feature/base

  echo "brand new" > new-file.txt
  git add new-file.txt
  git commit -q -m "add new file"
  git push -q -u origin feature/base

  echo "modify" >> new-file.txt
  git add new-file.txt

  # This should succeed even though new-file.txt doesn't exist on master
  printf 's\nn\n' | git-cmt -m "modify new file"

  assert_on_branch feature/base
  assert_branch_exists torbenn/modify-new-file
}

@test "[s] restores unstaged changes" {
  git checkout -b feature/base
  git push -q -u origin feature/base

  echo "staged" >> file.txt
  git add file.txt
  echo "wip" > unstaged.txt

  printf 's\nn\n' | git-cmt -m "stacked"

  assert_on_branch feature/base
  assert_file_exists unstaged.txt
  assert_file_contains unstaged.txt "wip"
  assert_stash_empty
}
