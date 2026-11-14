.DEFAULT_GOAL := help

COMPOSE ?= docker compose
COMPOSE_FLAGS ?=
SERVICE ?= app
SERVICES ?=
EXEC_USER ?=
EXEC_SHELL ?= sh
LOG_TAIL ?= 100

DC = $(strip $(COMPOSE) $(COMPOSE_FLAGS))

.PHONY: help env init config up up-app build rebuild stop down restart ps logs \
	app app-local shell root db redis \
	restart-mailpit restart-postgres restart-redis restart-app restart-nginx

help: ## コマンド一覧を表示
	@awk 'BEGIN {FS = ":.*## "} /^[a-z][a-z-]*:.*## / {printf "  make %-14s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

env: ## .envがなければ安全なローカル設定を作成（既存ファイルは保持）
	@sh scripts/init-env.sh

init: env ## 初回セットアップ: .env作成・構成確認・Rustイメージビルド・インフラ起動
	$(DC) --profile app config --quiet
	$(DC) build app
	$(DC) up -d --wait postgres redis mailpit

config: env ## 通常・appプロファイル・DB公開用のCompose設定を検証
	$(DC) config --quiet
	$(DC) --profile app config --quiet
	$(DC) -f docker-compose.yml -f docker-compose.db-port.yml --profile app config --quiet

up: env ## PostgreSQL・Redis・Mailpitを起動
	$(DC) up -d --wait postgres redis mailpit

up-app: env ## Rust・Nginxを含めてビルド・起動（ソース未配置なら待機）
	mkdir -p html/app
	$(DC) --profile app up -d --build

build: env ## Rust開発イメージをビルド
	$(DC) build app

rebuild: env ## ベースイメージを取得し直し、キャッシュなしでRustイメージを再ビルド
	$(DC) build --pull --no-cache app

stop: ## 全コンテナを停止（任意: SERVICES="app nginx"）
	$(DC) --profile app stop $(SERVICES)

down: ## 全コンテナ・ネットワークを削除して停止（Volumeは保持）
	$(DC) --profile app down

restart: ## 全コンテナを再起動（任意: SERVICES=app）
	$(DC) --profile app restart --no-deps $(SERVICES)

restart-mailpit: ## Mailpitだけ再起動
	$(DC) --profile app restart --no-deps mailpit

restart-postgres: ## PostgreSQLだけ再起動
	$(DC) --profile app restart --no-deps postgres

restart-redis: ## Redisだけ再起動
	$(DC) --profile app restart --no-deps redis

restart-app: ## Rustだけ再起動
	$(DC) --profile app restart --no-deps app

restart-nginx: ## Nginxだけ再起動
	$(DC) --profile app restart --no-deps nginx

ps: ## 停止中を含めてコンテナの状態を表示
	$(DC) --profile app ps --all

logs: ## ログを追跡（任意: SERVICES="app nginx" LOG_TAIL=200）
	$(DC) --profile app logs --follow --tail=$(LOG_TAIL) $(SERVICES)

app: ## 起動済みRustコンテナにrootで入る
	$(DC) exec --user 0:0 app bash

app-local: ## 起動済みRustコンテナに開発ユーザーdevで入る
	$(DC) exec --user dev app bash

shell: ## 指定サービスに通常ユーザーで入る（SERVICE=postgres等、EXEC_USER指定も可）
	$(DC) exec $(if $(EXEC_USER),--user $(EXEC_USER)) $(SERVICE) $(EXEC_SHELL)

root: ## 指定サービスにrootで入る（既定: SERVICE=app）
	$(DC) exec --user 0:0 $(SERVICE) $(EXEC_SHELL)

db: ## PostgreSQLへpsqlで接続
	$(DC) exec postgres sh -c 'exec psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'

redis: ## Redisへredis-cliで接続
	$(DC) exec redis redis-cli
