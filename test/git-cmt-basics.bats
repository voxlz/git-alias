#!/usr/bin/env bats
# Tests for git-cmt: argument parsing, staging validation, commit message handling

load test_helper

setup() {
  setup_mocks
  setup_test_repo
}

teardown() {
  teardown_test_repo
}

# ─── Argument parsing ───

@test "parses -m 'message' as commit message" {
  echo "change" >> file.txt
  git add file.txt

  printf 't\n' | git-cmt -m "my message"

  assert_commit_message "my message"
}

@test "parses -m'message' (no space) as commit message" {
  echo "change" >> file.txt
  git add file.txt

  printf 't\n' | git-cmt -m"my message"

  assert_commit_message "my message"
}

@test "passes unknown flags through to git commit" {
  echo "change" >> file.txt
  git add file.txt

  # --allow-empty-message is a flag that git commit accepts
  printf 't\n' | git-cmt -m "test" --no-verify

  assert_commit_message "test"
}

# ─── Staging validation ───

@test "rejects when nothing staged and no -a flag" {
  echo "change" >> file.txt
  # deliberately not staging

  run bash -c 'printf "t\n" | git-cmt -m "test"'

  [ "$status" -ne 0 ]
  [[ "$output" == *"Nothing staged"* ]]
}

@test "rejects -a when nothing changed at all" {
  # repo is clean — no changes anywhere
  run bash -c 'printf "t\n" | git-cmt -a -m "test"'

  [ "$status" -ne 0 ]
  [[ "$output" == *"Nothing to commit"* ]]
}

@test "-a detects unstaged changes" {
  echo "change" >> file.txt
  # not staged, but -a should pick it up

  printf 't\n' | git-cmt -a -m "with add all"

  assert_commit_message "with add all"
}

@test "-a detects untracked files" {
  echo "new" > brand_new.txt
  # untracked, not staged

  printf 't\n' | git-cmt -a -m "untracked included"

  assert_commit_message "untracked included"
  assert_file_exists brand_new.txt
  # file should be tracked now
  git ls-files --error-unmatch brand_new.txt
}

# ─── Commit message prompt ───

@test "prompts for message when -m not given" {
  echo "change" >> file.txt
  git add file.txt

  printf 'my prompted message\nt\n' | git-cmt

  assert_commit_message "my prompted message"
}

@test "aborts when empty message entered at prompt" {
  echo "change" >> file.txt
  git add file.txt

  run bash -c 'printf "\nt\n" | git-cmt'

  [ "$status" -ne 0 ]
}
