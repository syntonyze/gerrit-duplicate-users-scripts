#!/bin/bash

function findFileByUserId() {
  local schema=$1
  local userId=$2
  grep --exclude-dir='.git' -l "$schema:" $(grep --exclude-dir='.git' -lr -B1 "$userId" .)
}

function findFileByUserIdInsensitively() {
  local schema=$1
  local userId=$2
  grep --exclude-dir='.git' -l "$schema:" $(grep --exclude-dir='.git' -ilr -B1 "$userId" .)
}

function computeNewFileName() {
  local schema=$1
  local userId=$2

  echo -n "$schema:$userId" | shasum | cut -d ' ' -f1
}

function normalizeUserNameInFile() {
  local filePath=$1
  local normalizedName=$2
  sed -E "s/(gerrit|username):(.+)\"]/\1:$normalizedName\"\]/" <"$filePath"
}

function checkoutExternalIds() {
  ALL_USERS_DIR=$1

  logInfo "Checkout refs/meta/external-ids"

  pushd "$ALL_USERS_DIR" &>/dev/null || {
    logErr "FATAL: Could not move to $ALL_USERS_DIR directory"
    exit 1
  }

  git fetch origin refs/meta/external-ids &&
    git checkout FETCH_HEAD
}

function getAllUserRefs() {
  git ls-remote 2>/dev/null | grep 'refs/users' | cut -d '/' -f4
}

function getAllUsernameFromExternalIds() {
  grep --exclude-dir='.git' -rh -A1 'username:' . 2>/dev/null | grep "accountId" | cut -d '=' -f2 | sed 's/ //g'
}

function getCamelCaseUsernames() {
  grep --exclude-dir='.git' -rh 'externalId "username:' * | cut -d ':' -f 2 | tr -d '"]' | egrep '[A-Z]'
}

function getCamelCaseUernamesSingleAppearance() {
  for i in $(getCamelCaseUsernames); do
    git grep -hi "username:$i" | tr '[:upper:]' '[:lower:]' | cut -d ':' -f 2 | tr -d '"]' | sort | uniq -c
  done | grep ' 1 ' | sed 's/ 1 //'
}

function backupAndDeleteBranch() {
  branchName=$1
  backupBranch=$(backupUserRefName "$branchName")

  logInfo "Backup user ref $branchName in ref $backupBranch"

  git fetch origin "$branchName" &>/dev/null
  git push origin FETCH_HEAD:"$backupBranch"

  logInfo "Delete user ref $branchName"
  git push origin --delete "$branchName"
}

function getUserRefName() {
  userId=$1
  git ls-remote --exit-code origin "refs/users/*/$userId" 2>/dev/null | cut -d$'\t' -f2
}

function backupUserRefName() {
  userRefName=$1
  echo "$userRefName" | sed 's/refs\/users/refs\/removed-users/'
}

function removeUsernameSchemaFile() {
  fileName=$1
  userId=$2

  logInfo "Remove 'username' entry in $fileName, for userId $userId"

  git rm "$fileName" && git commit \
    -m "[cleanup userId $userId] Remove spurious userId stored in $fileName" \
    -m "UserId $userId was found in a 'username:' schema file, however does not
have an equivalent entry in refs/users/ and as such it should be removed."
}

function removeGerritLdapSchemaFile() {
  fileName=$1
  userId=$2

  logInfo "Remove gerrit LDAP entry in $fileName, for userId $userId"

  git rm "$fileName" && git commit \
    -m "[cleanup userId $userId] Remove phantom userId stored in $fileName" \
    -m "UserId $userId was found in refs/users/, however does not
have an equivalent 'username:' schema entry and as such it should be removed."
}

function getUsernameFromFile() {
  filePath=$1
  head -1 "$filePath" | cut -d':' -f2 | tr -d '"]'
}

function getAccountIdFromFile() {
  filePath=$1
  grep accountId "$filePath" | cut -d'=' -f2 | xargs
}

function commitReplacement() {
  userId=$1

  git commit \
    -m "[clean up userId $userId] normalize camel-case name" \
    -m "UserId $userId had a mix of uppercase and lowercase letter, which has
been normalized to all lowercase letters."
}

function now() {
  date '+%s'
}

function logInfo() {
  echo "$(now)|INFO|$1"
}

function logErr() {
  echo >&2 "$(now)|ERROR|$1"
}
