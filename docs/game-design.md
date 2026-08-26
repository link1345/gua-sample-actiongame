# ゲーム企画書：Gua Signal Relay

## 1. 企画概要

### 一文で表すゲーム

人間の現場担当者とAIの管制担当者が、同じブラウザゲームを観測し、ゲーム内通信と遠隔操作を使って事故施設から脱出する短編トップダウンアクションゲーム。

### 企画目的

このゲームは、Gua WebMCPによって次の体験が成立することを短時間で示す。

- Canvas／WebGL内の状態をAIがSemantic UI Treeとして理解する
- 人間の行動がTreeへ反映され、AIの判断材料になる
- AIの操作がゲーム画面と人間の状況へ即座に反映される
- AIがゲーム内メッセージを送り、人間がゲーム内で応答する
- 人間とAIが互いを待ち、相談しなければ安全に攻略できない

AIにゲームを自動クリアさせることではなく、人間とAIの役割が異なる協力プレイを中心にする。

## 2. 仮タイトル

**Gua Signal Relay**

タイトルは変更可能。提出時には「人間とAIの通信」と「役割の受け渡し」が伝わる名称を優先する。

## 3. 対象環境

- Engine: Godot 4.7
- Language: GDScript
- Target: Web
- Renderer: `gl_compatibility`
- Input: Keyboard、必要に応じて画面上の方向ボタン
- Agent integration: Gua Semantic UI + WebMCP
- Session: ブラウザタブごとに独立
- External MCP server／WebSocket: ブラウザネイティブ経路では不要

## 4. プレイヤーの役割

### 人間：Field Operator

- WASDまたは矢印キーで移動する
- 危険物を避ける
- 指定地点、扉、退避エリアへ到達する
- ゲーム内端末でAIからの連絡を読む
- `Ready`、`Wait`、`Need shield`等の返答を送る
- AIが開いた短い安全時間を利用して進む

### AI：Control Operator

- `get_ui_tree`で現在の警告、電力、扉、シールド、人間の状態を読む
- 人間へゲーム内メッセージを送る
- 電力スライダー、シールド、経路選択、扉を操作する
- `wait_for_node`で人間の到着や安全条件を待つ
- 危険な操作の前に警告内容を考慮する
- 人間のゲーム内返答を読み、次の操作を決定する

## 5. 画面構成

```text
+---------------------------------------------------------------+
| Mission / HP / Current objective                              |
+--------------------------------------+------------------------+
|                                      | AI CONTROL CONSOLE     |
|       TOP-DOWN GAME FIELD            |                        |
|                                      | Power      [ 30% ]     |
| Human character                      | Route      [ Door A ]   |
| Doors / shield zones / laser         | Shield     [ OFF ]      |
| Goal                                 | Door A     [ LOCKED ]   |
|                                      |                        |
|                                      | Warning / status       |
+--------------------------------------+------------------------+
| COMMUNICATION TERMINAL                                        |
| AI: Wait at Door A. I will enable the shield first.           |
| [Ready] [Wait] [Need shield]                                  |
+---------------------------------------------------------------+
```

管制コンソールもGodotのControlノードとしてゲーム画面内へ表示し、人間とAIが同じ状態を見ていることを映像で示す。

## 6. MVPミッション

### ミッション名

**Escape from Sector A**

### 目標時間

初見でも2～3分。デモ撮影では約90秒で主要連携を見せられること。

### Beat 1：通信確認

- 人間が開始地点からDoor Aへ向かう
- AIはミッション説明と警告をTreeから読む
- AIが「Door Aへ向かってください」とゲーム内端末へ送信する
- 人間が`Ready`を押す

証明する機能：

- Treeからtextを読む
- `set_value`
- `click_node`
- 人間とAIの双方向通信

### Beat 2：危険な電力操作

Door Aの警告：

> Raising power above 80% opens Door A, but damages an unshielded field operator.

- 人間がDoor A前のArea2Dへ入る
- `partner-at-door-a` status nodeが出現する
- AIは`wait_for_node("partner-at-door-a")`で到着を待つ
- AIが先にシールドをONにする
- AIが電力を85%へ上げる
- Door Aが開く
- シールドなしで電力を上げた場合は人間がダメージを受ける

証明する機能：

- 状態待機
- 警告文の意味理解
- `set_checked`
- `set_value`
- 操作順序が結果へ影響する

### Beat 3：レーザー通路

- Door Aの先に周期レーザーがある
- AIは経路選択を`Maintenance`へ切り替えるとレーザーを一時停止できる
- 停止時間は数秒
- AIが「Go now!」と送る
- 人間が安全時間内に通過する
- 人間が出口Area2Dへ入ると`partner-at-exit`が出現する

証明する機能：

- `select`
- 人間のアクションとAI操作の時間的な協力
- 画面とTreeの同期

### Beat 4：脱出

- AIが出口ロックを解除する
- 人間がExitへ入る
- Mission Complete
- 人間とAIの通信履歴を短く表示する

## 7. 勝敗条件

### 勝利

- 人間が生存したままExitへ到達する
- AIが出口を開く
- 人間がExit Areaへ入る

### 失敗

- HPが0になる
- 電力過負荷を繰り返す
- レーザーに複数回接触する

MVPでは時間切れを必須にしない。撮影や審査中の不安定要因を増やさないため。

## 8. Semantic UI設計

### 主要ノード例

```text
mission-root
├─ mission-title
├─ current-objective
├─ field-operator-status
│  ├─ operator-hp
│  ├─ operator-location
│  └─ operator-shielded
├─ power-control
│  ├─ power-warning-title
│  ├─ power-warning-description
│  ├─ reactor-power
│  └─ shield-enabled
├─ route-control
│  ├─ power-route
│  ├─ door-a-control
│  └─ exit-control
└─ communication-terminal
   ├─ agent-message-draft
   ├─ send-agent-message
   ├─ received-agent-message
   ├─ human-ready
   ├─ human-wait
   └─ human-need-shield
```

### 条件成立時に出現するstatus node

- `partner-at-door-a`
- `partner-past-door-a`
- `partner-in-laser-corridor`
- `partner-at-exit`
- `door-a-open`
- `shield-active`
- `mission-complete`

MVPの`wait_for_node`はノード出現待ちなので、Area2Dやゲーム状態の成立時に対応statusを表示・登録する。

### テキストの構造

警告はtitleとdescriptionを別ノードにし、共通の親を持たせる。

```text
power-warning
├─ title: Warning
└─ description: Raising power above 80% damages an unshielded field operator.
```

AIが文脈を失わず、危険と対策を推論できることを優先する。

## 9. ゲーム内通信

### AIから人間

現行Guaの`set_value`は編集可能なLineEdit／TextEditへ使用する。

1. AIが`agent-message-draft`へ文字列を設定
2. AIが`send-agent-message`をクリック
3. ゲームが受信Labelへ反映
4. メッセージ履歴へ追加

表示Labelそのものを外部から直接書き換えず、通常の送信操作としてゲームロジックへ通す。

### 人間からAI

MVPでは即応しやすい定型ボタンを使う。

- Ready
- Wait
- Need shield
- Repeat

押された返答は画面上へ表示され、TreeからAIが読める。自由入力はMVP後の拡張候補とする。

## 10. WebMCPツール利用例

```text
get_ui_tree()
set_value("agent-message-draft", "Wait at Door A. I will enable the shield.")
click_node("send-agent-message")
wait_for_node("partner-at-door-a")
set_checked("shield-enabled", true)
set_value("reactor-power", "85")
wait_for_node("door-a-open")
set_value("agent-message-draft", "Door open. Go now!")
click_node("send-agent-message")
```

アプリ固有の複合ツールはMVP後に検討する。最初はGuaの汎用Semantic UIツールだけで協力体験が成立することを示す。

## 11. アート・音響方針

### アート

- シンプルな研究施設
- 暗い背景と高コントラストの管制UI
- 人間、扉、シールド、危険領域を色で識別
- 素材制作より状態の可読性を優先
- 第三者の商標や権利不明素材を使わない

### 音響

- 扉解錠
- シールド起動
- 警告
- 通信受信
- Mission Complete

動画で説明音声を邪魔しない音量にする。著作権のある音楽は使わない。

## 12. シーン・コード構成案

```text
project.godot
scenes/
  main.tscn
  game_world.tscn
  operator_console.tscn
  communication_terminal.tscn
scripts/
  main.gd
  mission_state.gd
  field_operator.gd
  hazard_controller.gd
  operator_console.gd
  communication_terminal.gd
addons/
  gua/
web/
  shell/
tests/
docs/
  game-design.md
```

`mission_state.gd`をゲーム状態のsource of truthとし、WorldとUIが同じ状態を参照する。JavaScript側だけでゲーム状態を模倣しない。

## 13. 実装フェーズ

### Phase 1：人間だけで遊べるゲーム

- Godot Webプロジェクト
- 移動、衝突、HP
- Door A、シールド、電力
- レーザー通路、Exit
- 管制UIを人間が手動操作可能
- Web Export

### Phase 2：Semantic UI

- Gua adapter導入
- 安定したnode ID
- warning、status、actionのTree反映
- click、set_value、set_checked、select、wait検証

### Phase 3：WebMCP

- #71のブラウザ経路を導入
- WebMCP tool登録
- ChatGPT in-app browserで検証
- 非対応ブラウザの明示表示
- 2タブ分離テスト

### Phase 4：公開・提出準備

- 公開URL
- 英語UIとREADME
- 3分未満のデモ動画
- 英語ナレーション／字幕
- テスト手順
- ライセンス表示
- 新規実装期間が分かるcommit履歴

## 14. MVP対象外

- オンラインマルチプレイヤー
- サーバー側セッション
- 外部WebSocket
- 複雑な戦闘AI
- 多数のステージ
- セーブデータ
- Unity版ゲーム
- AIによる連続的なキャラクター移動
- 高精度な物理アクション
- アプリ固有WebMCPツールの大規模設計

## 15. 3分デモ動画の構成

- 0:00–0:20：CanvasゲームをDOMから理解しにくい問題
- 0:20–0:35：人間がDoor Aへ移動
- 0:35–1:10：AIがTreeと警告を読み、ゲーム内通信
- 1:10–1:40：人間の到着待ち、シールド、電力、扉
- 1:40–2:10：レーザー通路で時間的に協力
- 2:10–2:30：Mission Completeと双方向通信履歴
- 2:30–2:45：2タブの状態分離
- 2:45–3:00：Gua Semantic UI → WebMCPの構造とGodot／Unityへの展開

## 16. 完成判定

- 人間だけでもMVPミッションを手動確認できる
- AIがGua WebMCPだけで管制担当の必須操作を完了できる
- 警告を無視した操作と、安全な順序の結果が画面上で異なる
- AIのメッセージがゲーム内に表示され、人間が応答できる
- 人間の位置条件をAIがwaitできる
- UI Treeと表示状態が同期する
- 公開Webビルドを審査環境から操作できる
- デモ動画が3分未満で中核体験を説明できる
