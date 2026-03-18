#!/usr/bin/env bats
# Tests for git-fp: force push with lease

load test_helper

setup() {
  setup_mocks
  setup_test_repo

  # Push initial state so we have a tracking branch
  git push -q -u origin master 2>/dev/null || true
}

teardown() {
  teardown_test_repo
}

# ─── Basic force-push ───

@test "force pushes current branch" {
  echo "change" >> file.txt
  git add file.txt
  git commit -q -m "local commit"

  # Amend to create divergence from remote
  echo "amended" >> file.txt
  git add file.txt
  git commit -q --amend --no-edit

  git-fp

  # Remote should have our amended commit
  local remote_sha local_sha
  remote_sha=$(git ls-remote --heads origin master | awk '{print $1}')
  local_sha=$(git rev-parse HEAD)
  [ "$remote_sha" = "$local_sha" ]
}

@test "fails when remote has diverged (lease rejection)" {
  echo "change" >> file.txt
  git add file.txt
  git commit -q -m "local commit"
  git push -q origin master

  # Simulate remote advancement by pushing directly to bare repo
  local tmp
  tmp=$(mktemp -d)
  git clone -q "$REMOTE_DIR" "$tmp/clone"
  cd "$tmp/clone"
  git config user.email "other@test.com"
  git config user.name "Other"
  echo "remote change" >> file.txt
  git add file.txt
  git commit -q -m "remote commit"
  git push -q origin master
  cd "$TEST_DIR"
  rm -rf "$tmp"

  # Now amend locally — remote has moved forward
  echo "amended" >> file.txt
  git add file.txt
  git commit -q --amend --no-edit

  run git-fp

  [ "$status" -ne 0 ]
}

@test "passes extra flags through" {
  echo "change" >> file.txt
  git add file.txt
  git commit -q -m "commit"

  echo "amend" >> file.txt
  git add file.txt
  git commit -q --amend --no-edit

  # Pass explicit remote/branch
  git-fp origin master

  local remote_sha local_sha
  remote_sha=$(git ls-remote --heads origin master | awk '{print $1}')
  local_sha=$(git rev-parse HEAD)
  [ "$remote_sha" = "$local_sha" ]
}
