#!/bin/sh
set -eu

# Never source or overwrite an existing .env: it may contain private settings.
if [ -e .env ] || [ -L .env ]; then
    printf '%s\n' '既存の .env を保持します。'
    exit 0
fi

umask 077
env_tmp=$(mktemp .env.tmp.XXXXXX)
trap 'rm -f "$env_tmp"' EXIT
trap 'exit 1' HUP INT TERM

env_password=$(od -An -N24 -tx1 /dev/urandom | tr -d ' \n')
if [ "${#env_password}" -ne 48 ]; then
    printf '%s\n' 'DBパスワードを生成できませんでした。' >&2
    exit 1
fi

env_uid=$(id -u)
env_gid=$(id -g)
if [ "$env_uid" -eq 0 ] || [ "$env_gid" -eq 0 ]; then
    printf '%s\n' '非rootの開発ユーザーで make init / make env を実行してください。' >&2
    exit 1
fi

sed \
    -e "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$env_password/" \
    -e "s/^LOCAL_UID=.*/LOCAL_UID=$env_uid/" \
    -e "s/^LOCAL_GID=.*/LOCAL_GID=$env_gid/" \
    .env.example > "$env_tmp"

# A hard link installs the file atomically and fails if .env now exists.
ln "$env_tmp" .env
printf '%s\n' '.env を作成しました（ランダムDBパスワード・ホストのUID/GIDを設定）。' \
    'HTTP_PORTは.env.exampleの値です。既存環境と併用する場合は起動前に変更してください。'
