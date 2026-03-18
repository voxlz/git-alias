#!/usr/bin/env bats
# Tests for git-rb: fetch + interactive rebase onto origin/master with autosquash

load test_helper

setup() {
  setup_mocks
  setup_test_repo
}

teardown() {
  teardown_test_repo
}

# ─── Basic rebase ───

@test "rebases branch onto origin/master" {
  # Create a feature branch
  git checkout -b feature

  echo "feature work" >> file.txt
  git add file.txt
  git commit -q -m "feature commit"

  # Advance master on remote
  local tmp
  tmp=$(mktemp -d)
  git clone -q "$REMOTE_DIR" "$tmp/clone"
  cd "$tmp/clone"
  git config user.email "other@test.com"
  git config user.name "Other"
  echo "remote" > remote.txt
  git add remote.txt
  git commit -q -m "remote advance"
  git push -q origin master
  cd "$TEST_DIR"
  rm -rf "$tmp"

  # Rebase — GIT_SEQUENCE_EDITOR=: makes -i non-interactive
  GIT_SEQUENCE_EDITOR=: git-rb

  # Feature commit should be on top of remote advance
  assert_commit_message "feature commit"
  git log --oneline | grep -q "remote advance"
}

@test "autosquashes fixup commits" {
  echo "base" >> file.txt
  git add file.txt
  git commit -q -m "base change"
  git push -q origin master

  git checkout -b feature

  echo "feature" >> file.txt
  git add file.txt
  git commit -q -m "feature work"

  echo "fix" >> file.txt
  git add file.txt
  git commit -q --fixup HEAD

  # Before rebase: 3 commits on feature (init, feature work, fixup)
  local before_count
  before_count=$(git rev-list --count HEAD)

  GIT_SEQUENCE_EDITOR=: git-rb

  # After autosquash: fixup should be squashed into "feature work"
  local after_count
  after_count=$(git rev-list --count HEAD)
  [ "$after_count" -lt "$before_count" ]
  assert_commit_message "feature work"
}

@test "passes extra flags through" {
  git checkout -b feature

  echo "change" >> file.txt
  git add file.txt
  git commit -q -m "work"

  # --no-stat is a valid rebase flag
  GIT_SEQUENCE_EDITOR=: git-rb --no-stat

  assert_commit_message "work"
}

# ─── Config dependency ───

@test "autosquash requires rebase.autoSquash config" {
  echo "base" >> file.txt
  git add file.txt
  git commit -q -m "base change"
  git push -q origin master

  git checkout -b feature

  echo "feature" >> file.txt
  git add file.txt
  git commit -q -m "feature work"

  echo "fix" >> file.txt
  git add file.txt
  git commit -q --fixup HEAD

  # Disable autoSquash — fixup should NOT be squashed
  git config rebase.autoSquash false

  local before_count
  before_count=$(git rev-list --count HEAD)

  GIT_SEQUENCE_EDITOR=: git-rb

  # Commit count unchanged means fixup was NOT squashed
  assert_commit_count "$before_count"
}
