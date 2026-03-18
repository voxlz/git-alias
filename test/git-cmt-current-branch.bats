#!/usr/bin/env bats
# Tests for git-cmt: commit to current branch ([t] option)

load test_helper

setup() {
  setup_mocks
  setup_test_repo
}

teardown() {
  teardown_test_repo
}

# ─── [t] Commit to current branch ───

@test "[t] commits to current branch" {
  echo "change" >> file.txt
  git add file.txt

  printf 't\n' | git-cmt -m "direct commit"

  assert_on_branch master
  assert_commit_message "direct commit"
  assert_commit_count 2
}

@test "[t] with -a stages and commits everything" {
  echo "change" >> file.txt
  echo "new" > new.txt

  printf 't\n' | git-cmt -a -m "add all commit"

  assert_commit_message "add all commit"
  git ls-files --error-unmatch new.txt
}

@test "[t] preserves unstaged changes" {
  echo "staged" >> file.txt
  git add file.txt
  echo "unstaged extra" >> file.txt

  printf 't\n' | git-cmt -m "only staged"

  assert_commit_message "only staged"
  # The unstaged change should still be there
  assert_file_contains file.txt "unstaged extra"
  # Working tree should be dirty (unstaged change remains)
  [ -n "$(git diff)" ]
}

@test "[t] default choice (empty input) commits to current branch" {
  echo "change" >> file.txt
  git add file.txt

  # Just press enter — default is current branch
  printf '\n' | git-cmt -m "default branch"

  assert_on_branch master
  assert_commit_message "default branch"
}
