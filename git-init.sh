#!/usr/bin/env sh
set -Eeuo pipefail

REPO=$1
DOMAIN=$2

TEMP_WORKSPACE=/tmp/initial-index

if [ ! -d $REPO ]; then
    /bin/echo "Initializing index repo."

    # Initialize the bare repository.
    /usr/bin/git init --bare --initial-branch main ${REPO}

    # Create and push the initial commit.
    /bin/mkdir ${TEMP_WORKSPACE}
    cd ${TEMP_WORKSPACE}
    /bin/echo "{\"dl\":\"http://${DOMAIN}/dl\",\"api\":\"http://${DOMAIN}\"}" > config.json

    /usr/bin/git init --initial-branch main
    /usr/bin/git config user.email "git@${DOMAIN}"
    /usr/bin/git config user.name "Private Crate Registry"
    /usr/bin/git add config.json
    /usr/bin/git commit -m "Initial commit"
    /usr/bin/git remote add origin http://localhost/git/index
    /usr/bin/git push origin main

    cd /tmp
    /bin/rm -rf ${TEMP_WORKSPACE}
fi