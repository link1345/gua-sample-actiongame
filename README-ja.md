# Gua Signal Relay

人間の現場担当者とAIの管制担当者が、同じミッションを観測し、ゲーム内で連絡を取りながら協力するブラウザ向けアクションゲームです。

[Godot](https://godotengine.org/)と[Gua](https://github.com/link1345/gua)を使い、Canvas／WebGLゲームをSemantic UI Tree経由でWebMCP対応させるデモとして開発します。人間はキャラクターを直接操作し、AIはリアルタイムのUI Treeを読み、管制コンソールを操作し、条件を待ち、ゲーム内メッセージを人間へ送ります。

> 状態：企画・初期開発中。WebMCPランタイムは[Gua Issue #71](https://github.com/link1345/gua/issues/71)で実装中です。

[English](README.md) | 日本語

## ゲームの中心体験

舞台は事故が発生した研究施設です。

- **人間 — 現場担当者：** キーボードで移動し、危険区域を突破します。
- **AI — 管制担当者：** 警告とミッション状態を読み、電力を配分し、シールドと扉を操作して、ゲーム内端末から人間へ連絡します。
- **共有ゲーム状態：** 人間とAIは、同じブラウザゲームの状態を観測・変更します。

代表的な協力場面：

1. 人間がDoor Aへ到着する。
2. AIが「シールドなしで電力を80%より上げると、相棒がダメージを受ける」という警告を読む。
3. AIがゲーム内メッセージで人間に待機を求める。
4. AIがシールドを有効化し、電力を供給して扉を開ける。
5. 人間が先へ進み、AIは次のsemantic mission stateを待つ。

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
- AIから人間へ送るゲーム内メッセージ端末
- 人間側の返答操作
- ミッション条件を表すsemantic status node
- 公開URLへ配置できるWebビルド
- 2タブで開いた場合のゲーム状態分離

## 技術構成

- Godot 4.7
- GDScript
- Godot Web Export
- Gua Semantic UI
- ブラウザネイティブWebMCP
- `gl_compatibility` renderer

ブラウザネイティブ経路では、外部MCPサーバーやWebSocket接続を必要としません。

## 関連

- [Gua WebMCP対応 — Issue #71](https://github.com/link1345/gua/issues/71)
- [Semantic UI Tree公開ポリシー — Issue #72](https://github.com/link1345/gua/issues/72)
- [OpenAI WebMCP Challenge](https://openai.com/webmcp-challenge/)

## ライセンス

MIT
