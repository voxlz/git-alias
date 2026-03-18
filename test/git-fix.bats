#!/usr/bin/env bats
# Tests for git-fix: fixup commit creation

load test_helper

setup() {
  setup_mocks
  setup_test_repo
}

teardown() {
  teardown_test_repo
}

# ─── Basic fixup ───

@test "creates fixup commit for HEAD" {
  echo "change" >> file.txt
  git add file.txt

  git-fix HEAD

  assert_commit_message "fixup! init"
}

@test "creates fixup commit for specific commit ref" {
  echo "first" >> file.txt
  git add file.txt
  git commit -q -m "first"

  echo "second" >> file.txt
  git add file.txt
  git commit -q -m "second"

  echo "fix" >> file.txt
  git add file.txt

  first_sha=$(git rev-parse HEAD~1)
  git-fix "$first_sha"

  assert_commit_message "fixup! first"
  # Wait — fixup targets the given ref, so the message should reference "first"
  # Actually git commit --fixup uses the message of the *target* commit
  # Let me re-check: HEAD~1 is "first", but after "second" was committed,
  # HEAD is "second", HEAD~1 is "first"
  # git-fix HEAD~1 → git commit --fixup HEAD~1 → "fixup! first"
}

@test "creates fixup for HEAD~1" {
  echo "first" >> file.txt
  git add file.txt
  git commit -q -m "first change"

  echo "second" >> file.txt
  git add file.txt
  git commit -q -m "second change"

  echo "fix" >> file.txt
  git add file.txt

  git-fix HEAD~1

  assert_commit_message "fixup! first change"
}

@test "fails with nothing staged" {
  run git-fix HEAD

  [ "$status" -ne 0 ]
}

@test "fails with invalid commit ref" {
  echo "change" >> file.txt
  git add file.txt

  run git-fix nonexistent

  [ "$status" -ne 0 ]
}

@test "passes extra flags through" {
  echo "change" >> file.txt
  git add file.txt

  # --no-verify skips hooks — should still work
  git-fix HEAD --no-verify

  assert_commit_message "fixup! init"
}
