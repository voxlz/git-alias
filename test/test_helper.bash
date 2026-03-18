#!/usr/bin/env bash
# Test helper for git-cmt tests
# Sources: setup/teardown functions, assertion helpers, mock utilities

# ─── Temp repo management ───

setup_test_repo() {
  TEST_DIR=$(mktemp -d)
  ORIG_DIR="$PWD"
  cd "$TEST_DIR"

  git init -q
  git config user.email "test@test.com"
  git config user.name "Test User"
  git config rebase.autoSquash true
  git config rebase.updateRefs true

  echo "init" > file.txt
  git add .
  git commit -q -m "init"

  # Create a bare "remote" to simulate push
  REMOTE_DIR=$(mktemp -d)
  git init -q --bare "$REMOTE_DIR"
  git remote add origin "$REMOTE_DIR"
  git push -q -u origin master 2>/dev/null || git push -q -u origin HEAD:master

  # Put our bin dir on PATH so git finds git-cmt, and mocks override real commands
  export PATH="$MOCK_DIR:$BIN_DIR:$PATH"

  # Skip interactive PR prompt in tests
  export GIT_CMT_CREATE_PR=n
}

teardown_test_repo() {
  cd "$ORIG_DIR"
  rm -rf "$TEST_DIR" "$REMOTE_DIR" "$MOCK_DIR"
}

# ─── Mock setup ───

setup_mocks() {
  MOCK_DIR=$(mktemp -d)

  # Mock `git-create`: just does checkout -b <branch> [<base>]
  cat > "$MOCK_DIR/git-create" <<'MOCK'
#!/usr/bin/env bash
slug="$1"
base="$2"
branch="torbenn/$slug"
if [ -n "$base" ]; then
  git checkout -q -b "$branch" "origin/$base"
else
  git checkout -q -b "$branch"
fi
MOCK
  chmod +x "$MOCK_DIR/git-create"

  # Mock `gh`: record calls instead of actually hitting GitHub
  cat > "$MOCK_DIR/gh" <<'MOCK'
#!/usr/bin/env bash
echo "gh $*" >> "${MOCK_DIR}/gh_calls.log"
echo "https://github.com/test/repo/pull/1"
MOCK
  chmod +x "$MOCK_DIR/gh"
  # gh mock needs MOCK_DIR in its environment
  sed -i '' "s|\${MOCK_DIR}|$MOCK_DIR|g" "$MOCK_DIR/gh" 2>/dev/null || \
    sed -i "s|\${MOCK_DIR}|$MOCK_DIR|g" "$MOCK_DIR/gh"
}

# ─── Paths ───

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)"

# ─── Assertions ───

assert_branch_exists() {
  git rev-parse --verify "$1" >/dev/null 2>&1 || {
    echo "Expected branch '$1' to exist"
    return 1
  }
}

assert_branch_not_exists() {
  if git rev-parse --verify "$1" >/dev/null 2>&1; then
    echo "Expected branch '$1' to NOT exist"
    return 1
  fi
}

assert_on_branch() {
  local actual
  actual=$(git branch --show-current)
  [ "$actual" = "$1" ] || {
    echo "Expected to be on branch '$1', but on '$actual'"
    return 1
  }
}

assert_commit_message() {
  local expected="$1"
  local actual
  actual=$(git log -1 --format=%s)
  [ "$actual" = "$expected" ] || {
    echo "Expected last commit message '$expected', got '$actual'"
    return 1
  }
}

assert_file_contains() {
  grep -q "$2" "$1" || {
    echo "Expected file '$1' to contain '$2'"
    return 1
  }
}

assert_file_not_exists() {
  [ ! -f "$1" ] || {
    echo "Expected file '$1' to not exist"
    return 1
  }
}

assert_file_exists() {
  [ -f "$1" ] || {
    echo "Expected file '$1' to exist"
    return 1
  }
}

assert_clean_working_tree() {
  local status
  status=$(git status --porcelain)
  [ -z "$status" ] || {
    echo "Expected clean working tree, but got:"
    echo "$status"
    return 1
  }
}

assert_stash_empty() {
  local stash
  stash=$(git stash list)
  [ -z "$stash" ] || {
    echo "Expected empty stash, but got:"
    echo "$stash"
    return 1
  }
}

assert_commit_count() {
  local expected="$1"
  local actual
  actual=$(git rev-list --count HEAD)
  [ "$actual" -eq "$expected" ] || {
    echo "Expected $expected commits, got $actual"
    return 1
  }
}
