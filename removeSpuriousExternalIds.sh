#!/bin/bash

###########################################################################################
# Remove spurious external-ids that do not have an equivalent in the refs/users/xx/xxxxxx #
###########################################################################################

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
ALL_USERS_DIR=$1

# shellcheck disable=SC1090
source "$SCRIPT_DIR"/utils.sh

logInfo "START - clean up of spurious external ids"

checkoutExternalIds "$ALL_USERS_DIR" || {
  logErr "FATAL: Could not checkout refs/meta/external-ids branch. Aborting."
  exit 1
}

ALL_EXTERNAL_IDS=$(getAllUsernameFromExternalIds)
ALL_USER_REFS=$(getAllUserRefs)

for userId in $ALL_EXTERNAL_IDS; do
  if ! (echo "$ALL_USER_REFS" | grep -q "$userId"); then
    fileName=$(findFileByUserId "username" "$userId")
    removeUsernameSchemaFile "$fileName" "$userId"
  fi
done

popd

logInfo "END - clean up of spurious external ids"
