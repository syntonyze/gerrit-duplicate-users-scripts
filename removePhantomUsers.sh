#!/bin/bash

#NOTE: need to check sandbox
##################################################################################
# Remove users that have an entry in the refs/users/xx/xxxxxx, but do not have a #
# "username:" schema entry in in the refs/meta/external-ids                      #
##################################################################################

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
ALL_USERS_DIR=$1

# shellcheck disable=SC1090
source "$SCRIPT_DIR"/utils.sh

logInfo "START - clean up phantom users"

checkoutExternalIds "$ALL_USERS_DIR" || {
  logErr "FATAL: Could not checkout refs/meta/external-ids branch. Aborting."
  exit 1
}

ALL_EXTERNAL_IDS=$(getAllUsernameFromExternalIds)
ALL_USER_REFS=$(getAllUserRefs)

for userId in $ALL_USER_REFS; do
  if ! (echo "$ALL_EXTERNAL_IDS" | grep -q "$userId"); then
    ldapFileName=$(findFileByUserId "gerrit" "$userId")
    removeGerritLdapSchemaFile "$ldapFileName" "$userId"

    useRefName=$(getUserRefName "$userId")
    backupAndDeleteBranch "$useRefName"
  fi
done

popd

logInfo "END - clean up phantom users"
