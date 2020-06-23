#!/bin/bash

set -e
set -u

GENERATED_SECRET="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)"
PARAM_FILE="${APP_ROOT}/config/parameters.yml"
SATIS_FILE="${APP_ROOT}/satis.json"

: ${APP_ROOT:?must be set}
: ${SECRET:=$GENERATED_SECRET}
: ${GITLAB_SECRET:=$GENERATED_SECRET}
: ${GITLAB_AUTO_ADD_REPO:=false}
: ${GITLAB_AUTO_ADD_REPO_TYPE:=gitlab}
: ${GITHUB_SECRET:=$GENERATED_SECRET}
: ${ADMIN_AUTH:=false}
: ${ADMIN_USERS:=\~}

: ${SSH_PRIVATE_KEY:=unset}
: ${ADD_HOST_KEYS:=false}
: ${STRICT_HOST_KEY_CHECKING:-default set down below}

: ${REPO_NAME:=myrepo}
: ${HOMEPAGE:=http://localhost:8080}

: ${CRON_ENABLED:=true}
: ${CRON_SYNC_EVERY:=60}

if [[ ! -e ${PARAM_FILE} ]]; then
  cat >${PARAM_FILE} <<EOF
parameters:
  secret: "${SECRET}"
  gitlab.secret: "${GITLAB_SECRET}"
  gitlab.auto_add_repo: "${GITLAB_AUTO_ADD_REPO}"
  gitlab.auto_add_repo_type: "${GITLAB_AUTO_ADD_REPO_TYPE}"
  github.secret: "${GITHUB_SECRET}"
  satis_filename: "%kernel.project_dir%/satis.json"
  satis_log_path: "%kernel.project_dir%/var/satis"
  admin.auth: ${ADMIN_AUTH}
  admin.users: ${ADMIN_USERS}
  composer.home: "%kernel.project_dir%/.composer"
EOF
fi


if [[ "${SSH_PRIVATE_KEY}" != "unset" ]] && [[ ! -e ${APP_ROOT}/id_rsa ]]; then
  cp ${SSH_PRIVATE_KEY} ${APP_ROOT}/id_rsa
  chmod 400 ${APP_ROOT}/id_rsa
  chown ${APP_USER}:${APP_USER} ${APP_ROOT}/id_rsa
fi

if [[ ! -e ${APP_ROOT}/.ssh/config ]]; then
  : ${STRICT_HOST_KEY_CHECKING:=no}
  cat >${APP_ROOT}/.ssh/config <<EOF
Host *
IdentityFile ${APP_ROOT}/id_rsa
StrictHostKeyChecking ${STRICT_HOST_KEY_CHECKING}
EOF
chmod 400 ${APP_ROOT}/.ssh/config
chown ${APP_USER}:${APP_USER} ${APP_ROOT}/.ssh/config
fi

if [[ ! -e ${SATIS_FILE} ]]; then
  cat >${SATIS_FILE} <<EOF
{
    "name": "${REPO_NAME}",
    "homepage": "${HOMEPAGE}",
    "repositories": [
    ],
    "require-all": true,
    "providers": true,
    "archive": {
        "directory": "dist",
        "format": "zip",
        "skip-dev": false
    }
}
EOF
    chmod 0777 ${SATIS_FILE}
fi

if [[ "${CRON_ENABLED}" == "true" ]]; then
  gosu ${APP_USER}:${APP_USER} /sync_repos.sh ${CRON_SYNC_EVERY}&
fi

if [[ ${ADD_HOST_KEYS} == "true" ]]; then
  : ${STRICT_HOST_KEY_CHECKING:=yes}
  while inotifywait -e close_write ${SATIS_FILE}; do
    gosu ${APP_USER}:${APP_USER} /record_host_fingerprint.sh
  done&
fi

if [[ "${1:-unset}" == "satisfy" ]]; then
  echo >&2 "Fix access.."
  chown -R ${APP_USER}:${APP_USER} ${APP_ROOT}/satis.json
  echo >&2 "Starting Php.."
  touch /var/log/php-fpm.log
  php-fpm >/var/log/php-fpm.log 2>&1 &
  echo >&2 "Starting Nginx.."
  exec -- nginx
else
  exec -- sh
fi
