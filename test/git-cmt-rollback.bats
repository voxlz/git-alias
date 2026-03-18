#!/usr/bin/env bats
# Tests for git-cmt: rollback safety and state integrity

load test_helper

setup() {
  setup_mocks
  setup_test_repo
}

teardown() {
  teardown_test_repo
}

# ─── Rollback on push failure ───

@test "rollback: push failure restores original state" {
  echo "change" >> file.txt
  git add file.txt

  local before_sha
  before_sha=$(git rev-parse HEAD)
  local before_count
  before_count=$(git rev-list --count HEAD)

  # Break the remote so push fails
  git remote set-url origin /nonexistent/path

  run bash -c 'printf "n\nn\n" | git-cmt -m "will fail push"'

  # Should have rolled back
  assert_on_branch master
  assert_commit_count "$before_count"
  [ "$(git rev-parse HEAD)" = "$before_sha" ]
  assert_stash_empty
}

@test "rollback: push failure restores unstaged changes" {
  echo "staged" >> file.txt
  git add file.txt
  echo "unstaged wip" > wip.txt

  # Break remote
  git remote set-url origin /nonexistent/path

  run bash -c 'printf "n\nn\n" | git-cmt -m "will fail"'

  assert_on_branch master
  assert_file_exists wip.txt
  assert_file_contains wip.txt "unstaged wip"
  assert_stash_empty
}

# ─── State integrity ───

@test "no stash leak after successful [n] commit" {
  echo "change" >> file.txt
  git add file.txt

  printf 'n\nn\n' | git-cmt -m "test"

  assert_stash_empty
}

@test "no stash leak after successful [t] commit" {
  echo "change" >> file.txt
  git add file.txt

  printf 't\n' | git-cmt -m "test"

  assert_stash_empty
}

@test "no extra commits left on original branch after [n]" {
  local before_sha
  before_sha=$(git rev-parse HEAD)

  echo "change" >> file.txt
  git add file.txt

  printf 'n\nn\n' | git-cmt -m "test"

  [ "$(git rev-parse HEAD)" = "$before_sha" ]
}

@test "working tree is clean after [n] with no unstaged changes" {
  echo "change" >> file.txt
  git add file.txt

  printf 'n\nn\n' | git-cmt -m "test"

  assert_clean_working_tree
}

# ─── Rename preservation (cherry-pick advantage) ───

@test "cherry-pick preserves file rename" {
  git mv file.txt renamed.txt
  git add -A

  printf 'n\nn\n' | git-cmt -m "rename test"

  git checkout torbenn/rename-test
  assert_file_exists renamed.txt
  assert_file_not_exists file.txt
}

@test "cherry-pick preserves file deletion" {
  git rm file.txt
  git add -A

  printf 'n\nn\n' | git-cmt -m "delete test"

  git checkout torbenn/delete-test
  assert_file_not_exists file.txt
}
