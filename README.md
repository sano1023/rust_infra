# Repia Docker 開発環境（repia-docker）

Rust / Loco アプリを別リポジトリから配置するためのローカル開発環境です。アプリ本体、Loco初期化、Vue、テーブル、マイグレーション、本番環境は含みません。

## 構成

```text
repia/                         # repia-docker の clone 先
├── docker-compose.yml
├── docker-compose.db-port.yml  # ホストのDBクライアント用（任意）
├── .env                       # ローカル専用、Git対象外
├── .env.example
├── .gitignore
├── Makefile
├── README.md
├── scripts/init-env.sh        # .envの初期設定のみ。アプリは初期化しない
├── docker/
│   ├── rust/{Dockerfile,dev-start.sh,.dockerignore}
│   ├── nginx/{nginx.conf,default.conf}
│   └── postgres/init/.gitkeep
└── html/
    └── app/                   # repia-app を別途clone。未配置でもよい
```

| サービス | 固定バージョン | ホストからのアクセス |
| --- | --- | --- |
| Rust（公式stableリリース） | `1.99.1-bookworm` | 公開なし、Nginx経由 |
| PostgreSQL（公式） | `17.12-bookworm` | 標準では公開なし |
| Redis（公式） | `7.4.12-alpine3.22` | 公開なし |
| Nginx（公式stable） | `1.30.6-alpine3.24` | 通常 `http://localhost`、検証時 `http://localhost:8080` |
| Mailpit | `v1.32.0` | `http://localhost:8025` |
| ファイル監視 | `watchexec-cli 2.8.0` | Rustイメージに同梱 |

イメージはパッチ版と、選択できるものはOS系列まで固定しています。最新追従タグは使いません。タグの提供状況は[公式Rust](https://hub.docker.com/_/rust)、[公式PostgreSQL](https://hub.docker.com/_/postgres)、[公式Redis](https://hub.docker.com/_/redis)、[公式Nginx](https://hub.docker.com/_/nginx)、[Mailpitリリース](https://github.com/axllent/mailpit/releases/tag/v1.32.0)、[Watchexecリリース](https://github.com/watchexec/watchexec/releases/tag/v2.8.0)で確認できます。実際の検証状況は [VALIDATION.md](VALIDATION.md) を参照してください。

通常の `up` はPostgreSQL・Redis・Mailpitだけを起動します。`app` プロファイルを指定するとRust・Nginxも起動します。DB・Redis・Mailpitは内部ネットワークに置き、Mailpitに外部SMTPリレー・転送を設定していません。SMTPポート1025もホストには公開しません。

## Makeコマンド

GNU Makeが利用できる場合は、以下の短縮コマンドを使えます。引数なしの `make` / `make help` で一覧を表示します。`make init` はDocker環境の初期設定だけを行い、アプリ生成・Loco初期化・マイグレーションは実行しません。

| コマンド | 操作 |
| --- | --- |
| `make env` | `.env` がなければ作成。ランダムDBパスワード・ホストのUID/GIDを設定 |
| `make init` | `.env` 準備 → 構成確認 → Rustイメージのビルド → インフラ起動 |
| `make config` | 通常・アプリ込み・DBポート公開用のCompose設定を検証 |
| `make up` | PostgreSQL・Redis・Mailpitを起動し、準備完了を待つ |
| `make up-app` | Rust・Nginxを含めてビルド・起動。ソース未配置ならRustは待機 |
| `make build` | Rust開発イメージをビルド |
| `make rebuild` | ベースイメージをpullし、キャッシュなしでRust開発イメージを再ビルド |
| `make ps` | 停止中を含むコンテナの状態を表示 |
| `make logs` | 全サービスの直近100行と後続ログを表示 |
| `make stop` / `make down` | 停止 / コンテナ・ネットワークを削除して停止。どちらもVolumeを保持 |
| `make restart` | コンテナを再起動 |
| `make restart-mailpit` | Mailpitだけ再起動 |
| `make restart-postgres` / `make restart-redis` | PostgreSQL / Redisだけ再起動 |
| `make restart-app` / `make restart-nginx` | Rust / Nginxだけ再起動 |
| `make app-local` | 起動済みRustコンテナに開発ユーザー `dev` で接続 |
| `make app` | 起動済みRustコンテナに `root` で接続 |
| `make shell SERVICE=postgres` | 指定サービスへ、そのサービスの通常ユーザーで接続 |
| `make root SERVICE=postgres` | 指定サービスへrootで接続 |
| `make db` / `make redis` | `psql` / `redis-cli` で接続 |

初回からMakeを使う例です。新規 `.env` は通常用のポート80を引き継ぐため、既存環境と併用するときは先に8080へ変更します。今回作成済みの `.env` は8080を設定しており、Makeから上書きしません。

```bash
make env
# 新規.envの場合、HTTP_PORT=8080へ変更してから次へ進む
make init
make ps

# アプリ未配置でも起動可能。アプリのclone手順は後述
make up-app
make app-local
# コンテナ内で exit するとホストへ戻る
make app

make logs SERVICES="app nginx" LOG_TAIL=200
make restart SERVICES=app
make restart-mailpit
make shell SERVICE=redis
make shell SERVICE=app EXEC_USER=dev EXEC_SHELL=bash
make root SERVICE=nginx
make down
```

シェル接続コマンドは起動済みコンテナが対象です。Rustへ接続する前は `make up-app` を実行してください。通常のソース編集・Cargo操作は `make app-local` を使います。サービス自体は引き続き非rootで起動します。

サービス単位の再起動には `make restart-mailpit` のような専用コマンド、または `make restart SERVICES=mailpit` を使えます。複数を指定する場合は `make restart SERVICES="mailpit redis"` とします。`--no-deps` を付け、指定したサービスだけを再起動します。`SERVICES` を省略した `make restart` は全サービスが対象です。再起動は既存コンテナを対象とし、設定変更の反映に必要な再作成・ビルドは行いません。

`make up`・`make build`・`make up-app` も、`.env` がない場合は自動作成します。`make env` / `make init` は既存 `.env` の内容・権限を変更しません。新規作成にはLinux/macOSの `sh`、`mktemp`、`od`、`tr`、`sed`、`id` を使い、PythonやOpenSSLは不要です。

Composeの追加オプションも指定できます。例えばホストからDBへ接続する期間は、同じ `COMPOSE_FLAGS` を起動や再作成に指定します。

```bash
make up COMPOSE_FLAGS='-f docker-compose.yml -f docker-compose.db-port.yml'
```

## 1. 初回セットアップ

Docker Engine / Docker Desktop、Docker Compose v2（`up --wait` を使うため2.20以降を推奨）、Gitが必要です。LinuxではDockerデーモンへアクセスできるユーザーで実行してください。

```bash
git clone <repia-dockerのGit-URL> repia
cd repia
cp .env.example .env
chmod 600 .env
```

既に `.env` がある場合は上書きせず、その設定を利用してください。この作業で作成したローカル `.env` にはランダムなDBパスワードと `HTTP_PORT=8080` を設定しています。

`.env` の `POSTGRES_PASSWORD` をランダム値に変更します。例えば `openssl rand -hex 24` で生成できます。`DATABASE_URL` も同じ値から構成するため、パスワードには英数字・16進数を使ってください。`@`、`:`、`/`、`$` などを使う場合はURLエンコードとComposeの変数展開を別途考慮する必要があります。

Linuxでは `id -u` / `id -g` の値を `.env` の `LOCAL_UID` / `LOCAL_GID` に設定してください。非rootのRustユーザーをこのIDで作成し、ホスト側ソースへの書き込み権限を合わせます。

HTTPポートは `.env` の `HTTP_PORT` で変更できます。

- 通常運用の例: `HTTP_PORT=80`（`.env.example` の値）
- 今回の検証・既存環境と併用: `HTTP_PORT=8080`
- 既存環境が使っている **80・8123・8000では検証しません**。

全公開ポートは `127.0.0.1` にバインドします。8080や8025も使用中の場合は、起動前に `.env` で別の空きポートを指定してください。

```bash
docker compose config --quiet
docker compose --profile app config --quiet
docker compose up -d --wait
docker compose ps
```

`html/app/` は不要です。通常起動ではRustイメージのビルドもソースのマウントも行いません。`docker/postgres/init/` は空のまま用意しており、SQLは実行しません。将来ファイルを追加した場合、公式イメージは空のDB Volumeの初期化時だけそれらを実行します。

## 2. 起動・停止

```bash
# インフラのみ
docker compose up -d --wait

# アプリも利用する場合（初回はRustイメージをビルド）
mkdir -p html/app
docker compose --profile app up -d --build

# コンテナを残して停止・再開
docker compose --profile app stop
docker compose --profile app start

# コンテナとネットワークを削除して停止。データVolumeは保持
docker compose --profile app down
```

通常の停止に `down -v` や `docker volume prune` を使わないでください。Volume削除はデータを失う操作です。ヘルスチェックはDB・Redis・Mailpitの準備完了を待ちます。全サービスに `restart: unless-stopped` を設定しています。`unhealthy` 判定そのものは自動再起動を起こさないため、障害時はログを確認してください。

Rustは `Cargo.toml` がなければ正常に待機します。その状態でもNginxは起動でき、`/nginx-health` は204になります。アプリ未配置・コンパイル中の `/` は502です。Rustのヘルスチェックは未配置時の待機を正常とし、配置後は `/_ping` を確認します。異なるヘルスパスを使うアプリではComposeのチェックを合わせてください。NginxのチェックはNginx自身の稼働確認です。

## 3. 各コンテナへの接続

```bash
docker compose exec postgres sh
docker compose exec redis sh
docker compose exec mailpit sh
docker compose exec app bash
docker compose exec nginx sh

# ソースも依存サービスの起動も不要なツール確認
# html/appは空でよく、mkdirはホストユーザーの所有権で作るため
mkdir -p html/app
docker compose build app
docker compose run --rm --no-deps app rustc --version
docker compose run --rm --no-deps app cargo --version
docker compose run --rm --no-deps app rustup show
```

Rust・PostgreSQL・Redis・Mailpit・Nginxの各プロセスは非rootユーザーで動かします。Rustのビルド中だけユーザー作成等にrootを利用します。Rustは `base` と `development` ステージを分けているため、将来の本番用builder/runtimeを開発ツールから分離して追加できます。本番用ステージは今回作成していません。

## 4. PostgreSQLへの接続

```bash
# コンテナ内のUnixソケットで接続
docker compose exec postgres sh -c 'exec psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'

# 別コンテナからパスワード付きTCP接続を確認
docker compose run --rm --no-deps postgres sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" psql -h postgres -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT current_database(), current_user; SHOW server_encoding;"'
```

Rustからは `postgres:5432`、DB名・ユーザー・パスワードは `.env` の値を使います。DBはUTF-8で初期化します。`POSTGRES_*` の初期化設定は既存Volumeには再適用されません。既存DBの認証情報を変える場合はSQLによる変更も必要です。

GUIなどホスト側のDBクライアントが必要なときだけ追加ファイルを指定します。

```bash
docker compose -f docker-compose.yml -f docker-compose.db-port.yml up -d --wait postgres
# 接続先: 127.0.0.1:5432（POSTGRES_PORTで変更可）
# psql -h 127.0.0.1 -p 5432 -U repia -d repia_development -W
```

公開をやめるには `docker compose up -d postgres` で標準設定に戻します。追加ファイル利用中の構成変更には同じ `-f` 指定を使ってください。

## 5. Redisへの接続

```bash
docker compose exec redis redis-cli ping
# PONG
docker compose exec redis redis-cli
```

RustからのURLは `redis://redis:6379/0` です。Redisは内部ネットワークのみ・パスワードなしの開発専用設定です。AOFを有効化し、`redis_data` Volumeに永続化します。

## 6. アプリリポジトリの配置・Git管理

```bash
mkdir -p html
git clone <repia-appのGit-URL> html/app

# それぞれ独立したリポジトリとして操作
git status
git -C html/app status
git check-ignore html/app/Cargo.toml
```

`repia-docker` と `repia-app` は独立したGitリポジトリです。Docker側は `/html/app/` 全体を無視し、Submodule / `.gitmodules` を使いません。空の `html/app/` がある場合もcloneできますが、中にファイルがある場合は既存データを確認してください。コンテナの `target/` マウント用ディレクトリが残っている場合は、アプリコンテナ停止後にその空ディレクトリだけを取り除いてからcloneしてください。

この環境からアプリの作成・初期化・自動cloneは行いません。

## 7. 配置後の起動・ホットリロード

別途用意するLocoアプリは `0.0.0.0:5150` で待ち受ける必要があります。Composeは `DATABASE_URL`、`REDIS_URL`、`SMTP_HOST=mailpit`、`SMTP_PORT=1025`、`LOCO_ENV=development` を渡します。アプリ側の `config/development.yaml` でこれらを読み込んでください。任意の環境変数が自動でLoco設定に反映されるわけではありません。例えばDBの `uri` は `<%= get_env(name="DATABASE_URL") %>` を利用できます。SMTPはTLS・認証なしのMailpitを指定し、外部SMTPを使わないでください。接続設定の実装はアプリリポジトリで行います。[Locoの環境変数と設定](https://loco.rs/docs/reference/configuration/)を参照してください。

```bash
docker compose --profile app up -d --build
docker compose logs -f app
# 今回の.env（HTTP_PORT=8080）でのアクセス
curl --fail http://localhost:8080/_ping
```

通常のHTTPポート80に戻した場合は `http://localhost/_ping` にアクセスします。

起動コマンドの既定値は `cargo run -- start --binding 0.0.0.0 --port 5150` です。複数のバイナリを持つアプリなどでは `.env` の `APP_COMMAND` に `cargo run --bin <対象> -- start --binding 0.0.0.0 --port 5150` のように指定してください。

Watchexecがホストからマウントしたソースを1秒間隔で監視し、変更時にプロセスグループを停止して再コンパイル・再起動します。`target/` と `.git/` は監視対象外です。Cargo registry・Git依存・ビルド成果物をそれぞれ名前付きVolumeに保存します。Docker側の `.env` を変更した場合は `docker compose --profile app up -d` でコンテナを再作成してください。

空ディレクトリで待機させた後にcloneした場合は `docker compose restart app` で開始します。アプリの自動マイグレーション等はアプリ側の設定に従います。このDocker環境にマイグレーション実行コマンドは含みません。

## 8. ログの確認

```bash
docker compose --profile app ps
docker compose logs --tail=100 postgres redis mailpit
docker compose logs -f --tail=100 app nginx
```

ログは標準出力・標準エラーに出し、Docker側で10MB × 3ファイルにローテーションします。`docker compose config` の全出力には認証情報が含まれるため、共有する際は `--quiet` を使ってください。

## 9. Volumeのバックアップ・復元

Volume名の既定プレフィックスは `repia-docker_` です。`docker compose volumes` または `docker volume ls` で確認できます。DB稼働中のデータディレクトリをそのままtarで固めず、PostgreSQLは論理バックアップを使います。コマンドが失敗したバックアップは使用しないでください。

### バックアップ

```bash
mkdir -p backups
chmod 700 backups
umask 077

# PostgreSQL: 稼働中でも整合性のあるカスタム形式のダンプ
docker compose exec -T postgres sh -c \
  'exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom' \
  > backups/postgres.dump
```

Redisは書き込み元を停止し、Redisも正常停止してAOF一式を保存します。以下は起動済みアプリがある場合の手順です。インフラだけなら最初と最後のapp/nginx操作は不要です。

```bash
docker compose --profile app stop nginx app
docker compose stop redis
docker compose run --rm --no-deps -T redis sh -c 'tar -C /data -czf - .' \
  > backups/redis-data.tar.gz
docker compose up -d --wait redis
docker compose --profile app up -d
```

### 復元（別プロジェクトの新しいVolumeに復元）

既存開発データを上書きせず `repia-restore` という別プロジェクトで確認します。同名の復元環境を既に作っている場合は、未使用の別プロジェクト名に置き換えてください。`.env` はバックアップ時と同じDB名・ユーザーを使います。Mailpit・Nginxは起動しないため通常環境とホストポートが競合しません。

```bash
docker compose -p repia-restore up -d --wait postgres
docker compose -p repia-restore exec -T postgres sh -c \
  'exec pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner --no-privileges --exit-on-error' \
  < backups/postgres.dump

# Redisの空Volumeへ展開（空でなければ中断）
docker compose -p repia-restore run --rm --no-deps -T redis sh -c \
  'test -z "$(ls -A /data)" && tar -C /data -xzf -' \
  < backups/redis-data.tar.gz
docker compose -p repia-restore up -d --wait redis

docker compose -p repia-restore exec postgres sh -c \
  'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT current_database();"'
docker compose -p repia-restore exec redis redis-cli ping
docker compose -p repia-restore down
```

この手順は復元確認用です。開発環境の切り替えは復元先を確認してから行い、既存Volumeを削除して置き換える操作は含めていません。

Cargoの3つのVolumeは再生成できるキャッシュのため、通常はバックアップ不要です。UID/GIDを変更して再ビルドしても既存Volumeの所有者は変わりません。その場合は停止後に対象のCargoキャッシュVolumeだけを削除・再生成するか所有者を修正してください。PostgreSQL・RedisのVolumeには影響させないでください。

Mailpitの開発メールはコンテナ内の `/tmp` に保存します。コンテナ再作成時に消える一時データとして扱います。

## 10. Rust・PostgreSQLのバージョン更新

### Rust

1. `docker/rust/Dockerfile` の `FROM rust:<patch>-bookworm` を対象のstableリリースへ変更します。必要なら `WATCHEXEC_VERSION` も更新します。
2. アプリリポジトリの `rust-version` / `rust-toolchain.toml`、依存クレートの要件を確認します。別toolchainを指定したアプリではrustupが追加ダウンロードすることがあります。
3. `docker compose build --pull app` で再ビルドします。
4. `docker compose run --rm --no-deps app rustc --version` と `cargo --version` を確認し、アプリ配置後はアプリリポジトリのテストを実行してから `docker compose --profile app up -d` で反映します。

再現性のためコンテナ内だけで `rustup update` して更新を完了させず、Dockerfileのバージョンを更新します。キャッシュは新toolchainに合わせてCargoが再ビルドします。

### PostgreSQL

1. 上記の `pg_dump` でバックアップし、別Volumeで復元できることを確認します。
2. 同じメジャー17内の更新はComposeのパッチタグを変更し、`docker compose pull postgres`、`docker compose up -d --wait postgres` を実行します。
3. TCP接続・UTF-8・アプリ側の接続を確認します。
4. メジャー更新は既存Volumeに新イメージをそのまま接続しません。旧DBを残し、新しいVolumeへ論理バックアップを復元して検証します。PostgreSQL 18以降では公式イメージのデータパス・Volumeマウント方式も変わるため、リリースごとの公式手順を確認してください。

その他のイメージもComposeの固定タグを変更し、pull・ヘルスチェック・接続確認後に採用します。厳密なイメージ内容固定が必要な運用では、確認済みdigestも指定してください。
