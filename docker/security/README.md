# Rust開発コンテナのseccompプロファイル

`app-seccomp.json` はDocker標準のallowlistを基に、開発コンテナ内でCodexのbubblewrapサンドボックスを起動できるよう調整したものです。`app` サービスだけに適用します。

Dockerの標準設定では `codex sandbox -- pwd` も名前空間の作成時に失敗します。次の操作を追加で許可しています。

| 操作 | 追加した許可 |
| --- | --- |
| `clone` | `CLONE_NEWUSER` を含む場合のみ。Linux amd64/arm64の引数順に対応 |
| `unshare` | ユーザー名前空間などを作成 |
| `mount` | 内部サンドボックスのファイルシステムを構成 |
| `pivot_root` | 内部サンドボックスのルートを切り替え |
| `umount2` | 内部サンドボックスから旧ルートを取り除く |

既存のallowlist、既定の拒否動作、`clone3` のフォールバックなどは維持しています。`dev` ユーザーは非rootで実行し、`no-new-privileges:true` を維持します。`CAP_SYS_ADMIN` などの追加capabilityは付与していません。これらの操作に対するカーネルの権限チェックは引き続き適用されます。

## 元データ

- [moby/profilesのseccomp/default.json](https://github.com/moby/profiles/blob/f862455628f78f84c937e967e4a03902fb1dee11/seccomp/default.json)
- 参照コミット: `f862455628f78f84c937e967e4a03902fb1dee11`
- 取得日: 2026-11-15
- 元データのライセンス: Apache License 2.0（[LICENSE](LICENSE)）
- 変更点: 上記5操作の許可ルールを末尾に追加

更新時は標準プロファイルを全面的に許可する設定へ置き換えず、元データとの差分を確認してください。

## 動作確認

```bash
docker compose --profile app up -d --no-deps app
docker compose exec -T --user dev app codex sandbox -- pwd
```

名前空間の作成だけでなく、`workspace-write` モードで `/app` への書き込みが成功し、作業ディレクトリ外への書き込みが拒否されることも確認します。CLIのサンドボックスを無効化する設定は必要ありません。
