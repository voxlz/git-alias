#!/usr/bin/env bats
# Tests for git-sp: force-push the unmerged branch stack

load test_helper

setup() {
  setup_mocks
  setup_test_repo
}

teardown() {
  teardown_test_repo
}

@test "force pushes each branch in the current stack but not master" {
  git checkout -q -b middle
  echo "middle" > middle.txt
  git add middle.txt
  git commit -q -m "middle commit"
  git push -q -u origin middle

  git checkout -q -b top
  echo "top" > top.txt
  git add top.txt
  git commit -q -m "top commit"
  git push -q -u origin top

  git checkout -q middle
  echo "amended middle" >> middle.txt
  git add middle.txt
  git commit -q --amend --no-edit
  git checkout -q top
  git rebase -q --onto middle origin/middle top

  git-sp

  [ "$(git ls-remote --heads origin middle | awk '{print $1}')" = "$(git rev-parse middle)" ]
  [ "$(git ls-remote --heads origin top | awk '{print $1}')" = "$(git rev-parse top)" ]
  [ "$(git ls-remote --heads origin master | awk '{print $1}')" = "$(git rev-parse origin/master)" ]
}

@test "fails when the current branch is not based on the requested base" {
  git checkout -q --orphan unrelated
  git rm -q -rf .
  echo "unrelated" > unrelated.txt
  git add unrelated.txt
  git commit -q -m "unrelated commit"

  run git-sp origin/master

  [ "$status" -ne 0 ]
  [[ "$output" == *"not based on origin/master"* ]]
}