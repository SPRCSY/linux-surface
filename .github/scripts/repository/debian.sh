#!/usr/bin/env bash

set -euxo pipefail

apt-get()
{
    command apt-get -y "$@"
}

if [ -z "${GIT_REF:-}" ]; then
	echo "GIT_REF is unset!"
	exit 1
fi

if [ -z "${GITHUB_REPOSITORY:-}" ]; then
	echo "GITHUB_REPOSITORY is unset!"
	exit 1
fi

if [ -z "${SURFACEBOT_TOKEN:-}" ]; then
	echo "SURFACEBOT_TOKEN is unset!"
	exit 1
fi

if [ -z "${BRANCH_STAGING:-}" ]; then
	echo "BRANCH_STAGING is unset!"
	exit 1
fi

REPONAME="$(echo "${GITHUB_REPOSITORY}" | cut -d'/' -f2)"
REPO="https://surfacebot:${SURFACEBOT_TOKEN}@github.com/linux-surface/repo.git"

# parse git tag from ref
GIT_TAG="${GIT_REF#refs/tags/}"

# Install dependencies
apt-get update
apt-get install git openssl

# clone package repository
git clone -b "${BRANCH_STAGING}" "${REPO}" repo

# copy packages
find debian-latest -type f -exec cp {} repo/debian \;
pushd repo/debian || exit 1

# convert packages into references
while read -rd $'\n' FILE; do
    echo "${REPONAME}:${GIT_TAG}/$(basename "${FILE}")" > "${FILE}.blob"
    rm "${FILE}"
done <<< "$(find . -name '*.deb')"

RAND="$(openssl rand -hex 16)"
BRANCH="${BRANCH_STAGING}-${RAND}"

# set git identity
git config --global user.name "surfacebot"
git config --global user.email "surfacebot@users.noreply.github.com"

# commit and push
git checkout -b "${BRANCH}"
git add .
git commit -m "Update Debian ${REPONAME} package"
git push --set-upstream origin "${BRANCH}"

popd || exit 1