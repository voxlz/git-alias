#!/usr/bin/env bats
# Tests for git-amd: stage + fixup + autosquash rebase in one step

load test_helper

setup() {
  setup_mocks
  setup_test_repo
}

teardown() {
  teardown_test_repo
}

# ─── Basic amd (amend-squash) ───

@test "amends HEAD: fixup + rebase squashes into last commit" {
  echo "original" >> file.txt
  git add file.txt
  git commit -q -m "my commit"

  echo "fix" >> file.txt
  git add file.txt

  git-amd

  # Should still be "my commit" — fixup got squashed in
  assert_commit_message "my commit"
  assert_file_contains file.txt "fix"
}

@test "auto-stages all changes when nothing staged" {
  echo "original" >> file.txt
  git add file.txt
  git commit -q -m "my commit"

  echo "unstaged fix" >> file.txt
  # deliberately NOT staging

  git-amd

  assert_commit_message "my commit"
  assert_file_contains file.txt "unstaged fix"
}

@test "uses staged changes when something is staged" {
  echo "first" >> file.txt
  git add file.txt
  git commit -q -m "my commit"

  echo "staged" >> file.txt
  git add file.txt
  echo "unstaged" > other.txt

  git-amd

  assert_commit_message "my commit"
  assert_file_contains file.txt "staged"
  # unstaged file should NOT be committed
  assert_file_exists other.txt
  [ -n "$(git status --porcelain)" ]
}

@test "amends a specific older commit" {
  echo "first" >> file.txt
  git add file.txt
  git commit -q -m "first commit"

  echo "second" >> file.txt
  git add file.txt
  git commit -q -m "second commit"

  echo "fix for first" > fix.txt
  git add fix.txt

  git-amd HEAD~1

  # Both commits should still exist, second on top
  assert_commit_message "second commit"
  # First commit should now contain fix.txt
  git show HEAD~1 --name-only | grep -q "fix.txt"
}

@test "fails with invalid commit ref" {
  run git-amd nonexistent

  [ "$status" -ne 0 ]
}

@test "fails with nothing to commit" {
  # Clean working tree, nothing staged
  run git-amd

  [ "$status" -ne 0 ]
}

@test "preserves commit count when amending HEAD" {
  echo "change" >> file.txt
  git add file.txt
  git commit -q -m "my commit"

  local before_count
  before_count=$(git rev-list --count HEAD)

  echo "fix" >> file.txt
  git add file.txt

  git-amd

  assert_commit_count "$before_count"
}

@test "handles new untracked files with auto-stage" {
  echo "change" >> file.txt
  git add file.txt
  git commit -q -m "my commit"

  echo "brand new" > new.txt
  # untracked, not staged — amd should add -A

  git-amd

  assert_commit_message "my commit"
  git ls-files --error-unmatch new.txt
}

# ─── Config dependency ───

@test "autosquash requires rebase.autoSquash config" {
  echo "change" >> file.txt
  git add file.txt
  git commit -q -m "my commit"

  echo "fix" >> file.txt
  git add file.txt

  # Disable autoSquash — fixup stays as separate commit
  git config rebase.autoSquash false

  git-amd

  # Last commit should be the fixup, NOT squashed
  assert_commit_message "fixup! my commit"
}
