# Docker環境の検証記録

実施日: 2026-11-14（JST）

## 結果

構成の作成・静的検証は完了しています。Dockerデーモンへのアクセス制限により、**コンテナの実起動・DB/Redis接続・Rustツールチェーンの実行は未確認**です。実起動までの完了条件は満たしていません。

| 項目 | 結果 |
| --- | --- |
| `docker compose config --quiet` | 成功 |
| `docker compose --profile app config --quiet` | 成功 |
| DBポート公開用追加ファイルを含む `config --quiet` | 成功 |
| `html/app/` が存在しない状態での構成解決 | 成功。ディレクトリを作成せず確認 |
| インフラ通常起動 / Rust・Nginxのプロファイル分離 | 解決後のCompose設定で確認 |
| 検証HTTPポート8080 / 通常用サンプル80 | 解決後のCompose設定で確認。検証設定は80・8123・8000を使用しない |
| DB・Redisの非公開、公開ポートのlocalhost限定 | 解決後のCompose設定で確認 |
| ヘルスチェック・再起動・Volume・内部ネットワーク | 解決後のCompose設定で確認 |
| `sh -n docker/rust/dev-start.sh` | 成功 |
| Cargo.toml未配置時の待機処理 | ホストでスクリプトを起動し、1秒後も終了せず待機していることを確認。タイムアウトで終了 |
| `.env`・アプリ・バックアップのGit除外 | 一時Gitメタデータで `git check-ignore --no-index` を実行して確認 |
| `.env.example` を除外しないこと | 同上 |
| `.env` の権限 | 0600を確認。ランダムDBパスワードを設定 |
| PostgreSQL・Redis・Mailpitの起動 | 未確認。`docker compose up -d --wait` がDockerソケットへの接続時に失敗 |
| PostgreSQL・Redisへの実接続 | 未確認。コンテナを起動できないため |
| Rustイメージのビルド | 未確認。ビルダー設定の書き込み制限とDockerソケットのアクセス制限あり |
| `rustc --version` / `cargo --version` | 未確認。Rustイメージをビルド・実行できないため |
| Nginxの実設定検証・HTTP/WebSocket疎通 | 未確認。コンテナを起動できず、アプリも今回の対象外 |
| バックアップ・復元の実行 | 未確認。READMEに手順を記載 |

静的検証はイメージのpull・ビルド・サービス間通信の検証を代替しません。イメージタグは公式の掲載情報を参照していますが、この実行環境ではpullしていません。

アプリ本体・Cargoプロジェクト・Loco初期化・マイグレーション・Vueは一切作成していません。`html/app/` も未作成です。Docker側のGit除外設定とclone手順を用意しています。作業環境の `.git` は読み取り専用の空ディレクトリのため、この場でのGit初期化やリモート登録は行っていません。

## 実行環境の制限

Docker Client 29.1.3 / Compose v2.40.3-desktop.1 を確認しました。起動コマンドは次のエラーで停止しました。

```text
dial unix /var/run/docker.sock: connect: operation not permitted
```

権限拡張による `docker compose up -d --wait` も試みましたが、実行環境の自動承認ポリシー（`sandbox_approval: false`）が拒否しました。Dockerソケットの権限変更や既存コンテナへの操作は行っていません。

## Dockerへアクセスできる環境での再検証

以下は今回の `.env`（HTTP_PORT=8080）で実行します。80・8123・8000は使用しません。標準の `.env.example` から作り直した場合は、先に `.env` の `HTTP_PORT` を8080に変更してください。

```bash
# html/app/がない状態で最初に実行する
docker compose config --quiet
docker compose up -d --wait
docker compose ps

# 別コンテナからパスワード認証付きTCP接続。UTF-8も確認
docker compose run --rm --no-deps postgres sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" psql -h postgres -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "SELECT current_database(), current_user; SHOW server_encoding;"'
docker compose exec redis redis-cli ping
# 期待: PONG
curl --fail http://localhost:8025/readyz

# アプリのソースを作らずRustツールだけ検証
mkdir -p html/app
docker compose build app
docker compose run --rm --no-deps app rustc --version
docker compose run --rm --no-deps app cargo --version
docker compose run --rm --no-deps app rustup show

# 空のhtml/app/でも待機・Nginx起動が可能か確認
docker compose --profile app up -d --wait --wait-timeout 180
docker compose logs --tail=50 app
docker compose exec nginx nginx -t -c /etc/nginx/repia.conf
curl --fail --head http://localhost:8080/nginx-health
# 期待: 204。アプリがないので / の502は想定通り

# 停止時もデータVolumeを保持
docker compose --profile app down
```

HTTP/WebSocketのアプリへの実転送とRustのホットリロードは、別途開発された `repia-app` の配置後に追加検証してください。今回の検証のためにアプリを生成する必要はありません。

## Makefile追加時の検証

- `make help` がコマンド一覧を表示することを確認しました。
- `make config` が通常・appプロファイル・DB公開用の3構成すべてで成功しました。
- `make -n` で初期設定・起動・ビルド・状態表示・ユーザー別シェル・DB/Redis接続・ログ・停止の各コマンド展開を確認しました。
- 一時ディレクトリで `.env` の新規作成を実行し、48桁のランダム16進数パスワード、ホストのUID/GID、権限0600、通常用ポート80を確認しました。
- 既存 `.env` の内容・権限を上書きしないこと、作成失敗時に不完全な `.env` や一時ファイルを残さないことを確認しました。
- 作業ディレクトリの `.env` は変更しておらず、検証用ポート8080を保持しています。`html/app/` も未作成です。
- ホストのGIDがベースイメージ内に既にある場合も開発ユーザーを作れるよう、Dockerfileのグループ作成を調整しました。Dockerイメージの実ビルドは引き続き未確認です。
- `make ps` はComposeコマンドまで実行されましたが、Dockerソケットへの `operation not permitted` で停止しました。今回も実起動・コンテナ内のユーザー別接続は未確認です。
- サービス別の `make restart-mailpit` / `restart-postgres` / `restart-redis` / `restart-app` / `restart-nginx` を追加し、`make -n` で指定サービスだけを `restart --no-deps` に渡すことを確認しました。実際の再起動は行っていません。

## Stripe Sandbox追加時の検証（2026-11-15）

この節は上記の初期構築時とは別の検証です。今回はDockerデーモンへのアクセスが可能な環境で実施しました。

- `make config` で通常・app・app＋stripe・DB公開用の4構成が成功しました。
- 公式 `stripe/stripe-cli:v1.55.11` を基に専用イメージをビルドし、CLIのバージョンを確認しました。
- UID/GID 1000、全capability削除、ホストへのポート公開なし、専用の認証保存Volumeを確認しました。
- 設定ファイルの存在だけでは認証済みと判定せず、`stripe whoami` で確認し、未認証時は正常に待機することを確認しました。
- 開発用コマンドで `--live` を指定すると、外部APIを呼ぶ前に終了コード2で拒否することを確認しました。
- ユーザー自身のブラウザー認証後、`stripe whoami --format json` でテストモードへの接続を確認しました。
- 認証情報を保持したままStripeコンテナを再作成し、リスナーの `Ready!` を確認しました。署名シークレットは検証記録へ保存していません。
- 読み取り専用の `/v1/balance` 呼び出しが成功し、応答の `livemode: false` を確認しました。決済・契約・請求データの作成は行っていません。
- 認証情報ファイルの権限0600と所有者1000:1000を確認しました。
- 既存のRustアプリ・DB・Redis・Mailpit・Nginxは再作成していません。
- Webhookのアプリ受信は未検証です。確認時点で `app:5150` は接続拒否、既存appコンテナはunhealthyでした。またStripe用受信APIはアプリ側の後続実装です。Stripeリスナーの接続成功と、アプリでの受信成功は区別しています。

## アプリ起動とStripe受信実装の準備（2026-11-15）

- 起動前の開発DBを `backups/before-app-start-c99vrdua.dump` に権限0600で保存し、新規の専用一時DBへ復元できることを確認しました。検証後は自分で作成した一時DBだけを削除しました。
- 既存のサーバーバイナリが、その時点のRustソース更新時刻以降に作られたことを確認して起動しました。既存のCodex・Claude・テストを保持するため、コンテナの再作成・再起動は行っていません。
- アプリ側の既存 `.env` と暗号鍵を保持し、`APP_PUBLIC_URL` を実際のNginx公開URL、`TRUSTED_PROXY_IP` を現在のNginx接続元IPへ設定しました。
- Stripeリスナー用の `STRIPE_WEBHOOK_SECRET` と接続先の `STRIPE_ACCOUNT_ID` をアプリ側の `.env` へ保存しました。ファイルの権限0600とGit除外を確認し、値は文書へ記録していません。Stripe受信機能を実装するときに設定層で読み込む必要があります。
- アプリ内・Stripeコンテナからの `/_ready`、Nginx経由の `/_ping` と `/_ready` が成功し、`/auth/login` がHTTP 200で表示されることを確認しました。appのヘルスチェックはhealthyへ復旧しました。
- 現在はビルド済みバイナリのサーバープロセスを追加起動しています。ソース変更後は再ビルドしてサーバープロセスを再起動する必要があります。
- Stripe受信用APIの実装・署名検証・重複排除・実イベントのアプリ受信は、引き続きアプリ側の後続作業です。
