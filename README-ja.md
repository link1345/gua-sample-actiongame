# Gua Signal Relay

人間の現場担当者とAIの管制担当者が、同じミッションを観測し、AIとの直接会話で相談しながら協力するブラウザ向けアクションゲームです。

[Godot](https://godotengine.org/)と[Gua](https://github.com/link1345/gua)を使い、Canvas／WebGLゲームをSemantic UI Tree経由でWebMCP対応させるデモとして開発します。人間はキャラクターを直接操作し、AIはリアルタイムのUI Treeを読み、管制コンソールを操作し、条件を待ちます。会話はゲーム外のAI入力欄で行います。

> 状態：プレイ可能なMVPを実装済みです。Gua `v1.0.2`でGodot Web Release、Gua Semantic UI、ページ内WebMCP bundleをローカル検証しています。GitHub Pagesは`main`更新時にワークフローから公開されます。

[English](README.md) | 日本語

## ゲームの中心体験

舞台は事故が発生した研究施設です。

- **人間 — 現場担当者：** キーボードで移動し、電流計を確認しながら危険区域を突破します。AIとの相談はゲーム外の直接入力欄で行います。
- **AI — 管制担当者：** 人間には表示されない専用コンソールで警告とミッション状態を読み、電流、シールド、扉、レーザーを操作します。
- **共有ゲーム状態：** 人間とAIは、同じブラウザゲームの状態を観測・変更します。

代表的な協力場面：

1. タイトル画面でAIがWebMCPからゲームを開始する。人間にはボタンが見えるが押せない。
2. 人間がDoor Aへ到着する。
3. AIが「シールドなしで電流を80Aより上げると、相棒がダメージを受ける」という警告を読む。
4. AIがシールドを有効化し、電流を上げて扉を開ける。
5. 人間が先へ進み、AIは次のsemantic mission stateを読む。

## WebMCPを使う理由

Godot Web ExportはCanvas／WebGL上で動作するため、通常のDOMベース自動操作ではゲーム内のコントロールや状態を意味的に取得しにくいという問題があります。

Guaは、安定したnode ID、role、label、text、state、対応action、リクエスト相関付き完了を持つSemantic UI Treeを提供します。ゲームをホストするページがこれをWebMCPとして公開することで、ブラウザエージェントは座標やpixelを推測せず、構造化ツールで同じゲームを操作できます。

利用予定のツール：

- `get_ui_tree`
- `click_node`
- `set_value`
- `set_checked`
- `select`
- `wait_for_node`
- 対応時は`get_screenshot`

## MVP

最初のプレイ可能版は、2～3分で完了する短い1ミッションです。

- トップダウン方式のプレイヤー移動
- 電力配分パズル1つ
- シールドとダメージ警告
- 遠隔操作する扉2つ
- 移動または周期的に作動する危険物1つ
- AI専用の非表示Control Consoleと、人間専用の電流計
- ミッションイベントを表示する読み取り専用システムログ
- ゲーム外のAI入力欄を使った人間とAIの直接会話
- ミッション条件を表すsemantic status node
- 公開URLへ配置できるWebビルド
- 2タブで開いた場合のゲーム状態分離
- ミッションをまたいで維持される、人間専用の日英UI切替
- 位置、空間案内、危険状態を持つPlayer投影のWorld Object Tree

## 技術構成

- Godot 4.7
- GDScript
- Godot Web Export
- Gua Semantic UI
- ブラウザネイティブWebMCP
- `gl_compatibility` renderer

固定依存：

- Gua Godot addon `v1.0.2`
- `Gua.Testing` `v1.0.2`
- `Gua.Testing.Godot` `v1.0.2`
- `gua-webmcp` `v1.0.2`
- `gua-world-tools` `v1.0.2`

> Godot addonは公式Releaseの`gua-godot-addon-v1.0.2.zip`をSHA-256検証付きで導入します。Windows DebugとWeb Debug／Releaseのバイナリを同じarchiveから取得します。

ブラウザネイティブ経路では、外部MCPサーバーやWebSocket接続を必要としません。

Godot Canvas内でも日本語を安定表示するため、WebビルドにはSIL Open Font LicenseのM PLUS 1pを同梱しています。ライセンスは`assets/fonts/OFL-MPLUS1p.txt`に収録しています。

## 遊び方

1. AIがタイトルのSemantic UIを読み、`click_node("play-game")`を実行します。開始ボタンはマウス・キーボード入力を無視するため、人間だけでは開始できません。
2. 人間はWASDまたは矢印キーでField OperatorをDoor Aまで移動します。必要な相談はゲーム外のAI入力欄で行います。
3. AIは専用コンソールで`FIELD SHIELD`を有効にし、電流を80Aより上へ設定して`OPEN DOOR A`を押します。
4. 人間は表示された電流値を確認し、Door Aを通過します。
5. 人間は枠線で示されたレーザー待機地点で停止します。実際に到着した場合だけ、AIの`Suppress Laser 6s`が有効になります。
6. AIは操作前に「レーザーが消えたら走る」と伝えます。人間は停止後のAI返信を待たず、ビームの消灯を合図に6秒以内で通過します。
7. 人間がExtraction Zoneへ到着すると`RELEASE EXIT`が有効になり、AIが出口を解放します。

人間はタイトル画面・ミッション中を問わず、全UIを日本語／英語に切り替えられます。このボタンは`private`でAIのPlayer投影には出ません。ゲーム内には自由文の入力欄を置かず、読み取り専用のシステムログだけを選択言語で再描画します。

シールドなしで80Aを超えるとHPが減り、レーザーへ触れてもダメージを受けます。人間にはAI Control Consoleの内容や操作部品は表示されず、現在の電流値とシステムログだけが表示されます。

## ローカル実行とWebビルド

必要環境はGodot 4.7、PowerShell 7、Bunです。

```powershell
# Gua v1.0.2 Windows/Web addonを公式SHA-256検証付きで導入
.\scripts\install-gua.ps1

# 初回だけ。Godot公式アーカイブは約1.2GBです
.\scripts\install-godot-web-templates.ps1

# Godot起動確認、WebMCP型検査、Web Release生成
.\scripts\run-smoke.ps1
.\scripts\run-ui-tests.ps1
bun install --frozen-lockfile
bun run check:webmcp
.\scripts\build-web.ps1
```

成果物は`build/web/index.html`です。WebAssemblyのため、ファイルを直接開かずHTTPサーバーから配信してください。

Semantic actionを含むミッション試験：

```powershell
godot --headless --path . --script res://tests/mission_smoke.gd
```

この試験は開始前停止、AI専用開始、Player UI／World Object Tree、人間専用UIの除外、ゲーム内メッセージ入力欄の非公開、メートル単位の案内、ボタン前提条件、レーザー時刻とダメージ、目標遷移、日英再描画、脱出済み所在地、再プレイ時のAI再承認、相関完了を確認します。

`mission_smoke.gd`はゲーム内部で高速に状態遷移を検証する回帰試験です。これとは別に、`Gua.Testing.Godot`がGodotを別プロセスで起動し、WebSocket bridge越しに実際のSemantic UIを操作するUIテストを用意しています。

```powershell
.\scripts\run-ui-tests.ps1 -GodotExecutable "C:\path\to\Godot_v4.7-stable_win64_console.exe"
```

外部UIテストは、タイトルの説明とAI専用開始、開始前後のWorld Object公開状態、操作条件によるDoor Aの無効／有効化、`set_checked`／`set_value`／`click`の相関完了、開放後の状態公開を確認します。失敗時のGua diagnosticsはテスト出力の`artifacts/gua`へ保存されます。このテストはGitHub Pagesのビルドジョブでも実行します。

## AI Control Operator向け手順

WebMCP対応ブラウザでゲームを開くと、ページ内に`get_ui_tree`、`click_node`、`set_value`、`set_checked`、`select`、`wait_for_node`等が登録されます。安全な基本手順は次のとおりです。

```text
get_ui_tree()
click_node("play-game")
wait_for_node("partner-at-door-a")
set_checked("shield-enabled", true)
set_value("reactor-current", "85")
click_node("door-a-control")
wait_for_node("partner-at-laser-staging")
click_node("suppress-laser")
```

「レーザーが消えたら走る」などの相談や合図は、ゲーム内ツールではなく、このゲームをプレイしているAIとの直接会話で行います。

前提条件は安定ID `door-a-requirement`、`exit-requirement`、`laser-suppression-requirement`で公開します。読み取り専用の`laser-suppression-remaining`は、0～6秒の値を0.1秒単位で公開します。`play-game`はタイトル画面だけに現れ、再プレイ時もAIによるクリックが必要です。

AIコンソールには`operator-next-target`、`operator-next-direction`、`operator-next-distance`、`laser-staging-ready`も公開します。レーザーが再稼働した後も、`laser-suppression-started-at`、`laser-suppression-ends-at`、`laser-suppression-activation-id`から直前の停止履歴を確認できます。

`get_world_object_tree()`はミッション中、読み取り専用の7 object、`sector-a`、`field-operator`、`door-a`、`laser-staging-zone`、`laser-array`、`extraction-zone`、`exit-airlock`を公開します。位置単位はメートルで、operatorのzone、次目標、距離、シールド／HP、扉状態、レーザー時刻、出口準備状態をprimitive stateとして取得できます。

```text
get_world_object_tree()
find_world_objects({"id": "field-operator"})
find_world_objects({"id": "laser-array"})
```

レーザー接触は28HPで、最大1秒に1回です。停止終了そのものでは被弾せず、ビーム接触中だけダメージを受けます。再停止のクールダウンはありません。シールドなしで80A以下から80Aを超過させると34HPを失います。WebMCPの往復時間はブラウザエージェントに依存し、ゲーム側では保証しないため、後続のAI応答ではなく画面上の消灯を開始合図にします。

ブラウザ経路は常にGuaのPlayer投影を使います。AI専用Control Consoleはこの投影にだけ公開し、人間専用の電流計は`private`としてAIから除外します。人間用・AI用ともゲーム内メッセージ入力は公開しません。ゲーム状態とツール登録はタブごとに独立します。

## 関連

- [Gua WebMCP対応 — Issue #71](https://github.com/link1345/gua/issues/71)
- [Semantic UI Tree公開ポリシー — Issue #72](https://github.com/link1345/gua/issues/72)
- [OpenAI WebMCP Challenge](https://openai.com/webmcp-challenge/)

## ライセンス

MIT
