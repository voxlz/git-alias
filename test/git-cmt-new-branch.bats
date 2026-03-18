#!/usr/bin/env bats
# Tests for git-cmt: new branch from master ([n] option)

load test_helper

setup() {
  setup_mocks
  setup_test_repo
}

teardown() {
  teardown_test_repo
}

# ─── [n] New branch from master ───

@test "[n] creates branch with slugified name" {
  echo "change" >> file.txt
  git add file.txt

  printf 'n\nn\n' | git-cmt -m "Fix Login Bug"

  assert_branch_exists torbenn/fix-login-bug
}

@test "[n] cherry-picks commit onto new branch" {
  echo "change" >> file.txt
  git add file.txt

  printf 'n\nn\n' | git-cmt -m "my feature"

  # The new branch should have the commit
  git checkout torbenn/my-feature
  assert_commit_message "my feature"
  assert_file_contains file.txt "change"
}

@test "[n] returns to original branch" {
  echo "change" >> file.txt
  git add file.txt

  printf 'n\nn\n' | git-cmt -m "my feature"

  assert_on_branch master
}

@test "[n] removes temp commit from original branch" {
  echo "change" >> file.txt
  git add file.txt

  local before_count
  before_count=$(git rev-list --count HEAD)

  printf 'n\nn\n' | git-cmt -m "my feature"

  # Original branch should have same commit count as before
  assert_commit_count "$before_count"
}

@test "[n] restores unstaged changes after branching" {
  echo "staged" >> file.txt
  git add file.txt
  echo "unstaged work" > wip.txt

  printf 'n\nn\n' | git-cmt -m "my feature"

  assert_on_branch master
  assert_file_exists wip.txt
  assert_file_contains wip.txt "unstaged work"
  assert_stash_empty
}

@test "[n] pushes to remote" {
  echo "change" >> file.txt
  git add file.txt

  printf 'n\nn\n' | git-cmt -m "my feature"

  # Verify the branch exists on the remote
  git ls-remote --heads origin torbenn/my-feature | grep -q torbenn/my-feature
}

@test "[n] slug handles special characters" {
  echo "change" >> file.txt
  git add file.txt

  printf 'n\nn\n' | git-cmt -m "Fix: handle edge-case (v2)!"

  assert_branch_exists torbenn/fix-handle-edge-case-v2
}

@test "[n] slug handles uppercase" {
  echo "change" >> file.txt
  git add file.txt

  printf 'n\nn\n' | git-cmt -m "UPPERCASE MESSAGE"

  assert_branch_exists torbenn/uppercase-message
}

@test "[n] blocks when modified file doesn't exist on master" {
  # Create a feature branch with a file that doesn't exist on master
  git checkout -b feature
  echo "feature only" > feature-only.txt
  git add feature-only.txt
  git commit -q -m "add feature file"

  # Now modify the feature-only file (M status in diff)
  echo "modified" >> feature-only.txt
  git add feature-only.txt

  # Trying [n] (new from master) should fail: feature-only.txt doesn't exist on master
  run bash -c 'printf "n\n" | git-cmt -m "test"'

  [ "$status" -ne 0 ]
  [[ "$output" == *"Cannot move to new branch"* ]]
}

# ─── [n] with -a flag ───

@test "[n] with -a stages all and branches" {
  echo "change" >> file.txt

  printf 'n\nn\n' | git-cmt -a -m "auto stage"

  assert_on_branch master
  git checkout torbenn/auto-stage
  assert_commit_message "auto stage"
  assert_file_contains file.txt "change"
}
