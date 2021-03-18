#!/bin/bash

##################################################################################
# Normalize users that have only one 'username:', 'gerrit:' pair, which contains #
# a mix of lowercase and uppercase letters.                                      #
# The fix consists in lowercasing both schemas and recalculate the sha1 of the   #
# containing file                                                                #
##################################################################################

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
ALL_USERS_DIR=$1

# shellcheck disable=SC1090
source "$SCRIPT_DIR"/utils.sh

logInfo "START - normalize users with uppercase letters that have no duplicates"

checkoutExternalIds "$ALL_USERS_DIR" || {
  logErr "FATAL: Could not checkout refs/meta/external-ids branch. Aborting."
  exit 1
}

USERNAMES_SINGLE_APPEARANCE=$(getCamelCaseUernamesSingleAppearance)

for lowerCasedUserId in $USERNAMES_SINGLE_APPEARANCE; do
  # Normalize gerrit:UserName file
  schema="gerrit"
  ldapFileName=$(findFileByUserIdInsensitively $schema "$lowerCasedUserId")
  newLdapFileName=$(computeNewFileName $schema "$lowerCasedUserId")

  logInfo "Normalize ldap identity for $lowerCasedUserId (from $ldapFileName to $newLdapFileName)"

  normalizeUserNameInFile "$ldapFileName" "$lowerCasedUserId" >"$newLdapFileName"
  git rm "$ldapFileName" && git add "$newLdapFileName"

  # Normalize username:UserName file
  schema="username"
  gerritFileName=$(findFileByUserIdInsensitively $schema "$lowerCasedUserId")
  newGerritFileName=$(computeNewFileName $schema "$lowerCasedUserId")

  logInfo "Normalize gerrit identity for $lowerCasedUserId (from $gerritFileName to $newGerritFileName)"

  normalizeUserNameInFile "$gerritFileName" "$lowerCasedUserId" >"$newGerritFileName"
  git rm "$gerritFileName" && git add "$newGerritFileName"

  commitReplacement $(getAccountIdFromFile "$newGerritFileName")
done

popd

logInfo "END - normalize users with uppercase letters that have no duplicates"
