# Skillfy

🌍 [English](../README.md) | [한국어](./README.ko.md) | **日本語** | [中文](./README.zh.md)

![macOS: 対応](https://img.shields.io/badge/macOS-対応-brightgreen?style=for-the-badge&logo=apple&logoColor=white)
![Linux: 対応](https://img.shields.io/badge/Linux-対応-brightgreen?style=for-the-badge&logo=linux&logoColor=white)
![Windows: WSL使用](https://img.shields.io/badge/Windows-WSL使用-blue?style=for-the-badge&logo=windows&logoColor=white)

> **Windowsユーザーの方へ**: [WSL (Windows Subsystem for Linux)](https://learn.microsoft.com/ja-jp/windows/wsl/install)を使用してSkillfyを実行してください。

フィードバックを再利用可能なClaude Codeスキル(Skill)に変換しましょう。

Claude Codeプラグインで、フィードバックを継続的な学習に変えます。

## コンセプト

```
Claudeの出力が期待と異なる時
       ↓
/skillfyで記録
       ↓
/skillfy reviewでスキル(Skill)に昇格
       ↓
以降Claudeが自動的にルールを適用
```

## インストール

まずプラグインをローカルマーケットプレイスに追加し、インストールします：
```bash
/plugin marketplace add https://github.com/yhzion/claude-code-skillfy.git
/plugin install skillfy@claude-code-skillfy
```

### アップデート

```bash
/plugin marketplace update claude-code-skillfy
```

### アンインストール

プラグインを完全に削除するには、まずアンインストールしてからマーケットプレイスから削除します：
```bash
/plugin uninstall skillfy@claude-code-skillfy
/plugin marketplace remove claude-code-skillfy
```

## 使い方

### 初期化

```bash
/skillfy init
```

Skillfyのデータベースとディレクトリ構造を作成します。

> **注意**: SkillfyはGitリポジトリのルートにインストールされます。Gitリポジトリでない場合は、現在のディレクトリにインストールされます。

<details>
<summary>📖 詳細な使い方</summary>

**作成されるもの：**
- `.claude/skillfy/patterns.db` - SQLiteデータベース
- `.claude/skills/` - 昇格されたスキル(Skill)の保存ディレクトリ
- `.gitignore`にエントリを追加（Gitプロジェクトの場合）

**フロー：**

1. **確認：**
   - 「Skillfyを初期化しますか？」 → [はい、初期化する] [キャンセル]

2. **既に存在する場合：**
   - 「Skillfyは既に存在します」 → [維持] [再初期化（データを削除）]
   - 注：スキーマのアップグレードは再初期化で処理されます。インプレースマイグレーションはありませんので、必要に応じてデータをバックアップしてください。

3. **完了：**
   ```
   Skillfy初期化完了

   - .claude/skillfy/patterns.db 作成
   - .claude/skills/ ディレクトリ作成
   - .gitignore 更新（Gitプロジェクトの場合）

   これで/skillfyでミスマッチを記録できます。
   /skillfy reviewで保存したパターンをスキルに昇格できます。
   ```

</details>

---

### ミスマッチの記録

```bash
/skillfy
```

Claudeが期待と異なる出力を生成した時にパターンを記録します。

<details>
<summary>📖 詳細な使い方</summary>

> **スマート提案**: Claudeが現在のセッションコンテキストを分析し、各ステップで関連するオプションを動的に提案します。提案が合わない場合は「手動で入力」を選択できます。

**ステップ1: 状況の選択**（最大500文字）

Claudeが現在のセッションを分析して関連する状況を提案します：
```
パターンミスマッチの記録

どのような状況で発生しましたか？

1. {コンテキスト分析に基づく提案}
2. {最近のエラー/修正に基づく別の提案}
3. 手動で入力

選択：
```

**ステップ2: 期待の選択**（最大1000文字）

選択した状況に基づいてClaudeが期待を提案します：
```
何を期待していましたか？

1. {状況に基づく期待の提案}
2. {別の関連する期待}
3. 手動で入力

選択：
```

**ステップ3: 指示の選択**（最大2000文字）

Claudeが実行可能な指示を提案します：
```
Claudeはどのようなルールを学ぶべきですか？（命令形）

1. {提案される指示 - 例：「常にタイムスタンプフィールドを含める」}
2. {別の指示オプション}
3. 手動で入力

選択：
```

**ステップ4: アクションの選択**
```
記録の概要

状況：{状況}
期待：{期待}
指示：{指示}

どうしますか？

1. スキルとして登録 - すぐにスキルファイルを作成
2. メモとして保存 - 後で確認するためにDBに保存
3. キャンセル

選択：
```

</details>

---

### レビューとスキルへの昇格

```bash
/skillfy review
```

保存されたパターンをレビューし、スキル(Skill)に昇格します。

<details>
<summary>📖 詳細な使い方</summary>

**ステップ1: 保存されたパターンの表示**
```
保存されたパターン（まだ昇格されていません）

[id=12] モデル作成時 → 常にタイムスタンプフィールドを含める (2024-12-18)
[id=15] APIエンドポイント作成時 → 常にエラー処理を含める (2024-12-17)

昇格するパターンIDを入力してください（複数選択はカンマ区切り、キャンセルは'skip'）：
例：12 または 12,15
```

**ステップ2: スキルのプレビュー**
```
スキルプレビュー：{状況}

---
name: {ケバブケースの状況}
description: {指示}。{状況}の状況で自動適用。
learned_from: skillfy ({作成日})
---

## ルール

{指示}

## 適用対象

- {状況}

## 例

### 良い例

（ここに良い例を追加）

### 悪い例

（ここに悪い例を追加）

## 学習履歴

- 作成日：{作成日}
- ソース：/skillfyによる手動記録

---

[保存] [編集] [スキップ]
```

**ステップ3: 結果**
```
✅ スキル作成完了

- .claude/skills/{スキル名}/SKILL.md

🔄 このスキルを有効にするには、Claude Codeを再起動してください。
```

</details>

---

### ヘルプの表示

```bash
/skillfy help
```

利用可能なコマンドと現在の状態を表示します。

<details>
<summary>📖 詳細な使い方</summary>

**出力（初期化済みの場合）：**
```
📚 Skillfyヘルプ

状態：✅ 初期化済み | パターン：{件数} | スキル：{件数} | 保留中：{件数}

コマンド：
  /skillfy init      Skillfyを初期化
  /skillfy           期待とのミスマッチを記録
  /skillfy review    パターンをスキルに昇格
  /skillfy reset     すべてのデータを削除
  /skillfy help      このヘルプを表示

クイックスタート：
  1. /skillfy init → 2. /skillfy → 3. /skillfy review
```

</details>

---

### データのリセット

```bash
/skillfy reset
```

⚠️ すべてのパターン記録を削除します。作成されたスキルは保持されます。

<details>
<summary>📖 詳細な使い方</summary>

**オプション：**
- `/skillfy reset` - データベース記録のみ削除（スキルは保持）
- `/skillfy reset --all` - スキルを含むすべてを削除
  > ⚠️ **警告**：このオプションは、Skillfy以外のスキルを含む`.claude/skills/`ディレクトリ全体を削除します。このオプションを使用する前に、重要なスキルをバックアップしてください。

**ステップ1: 現在の状態**
```
⚠️ Skillfyリセット

データベースファイル：
- {DB_PATH}

削除されるデータ：
- {件数}件のパターン

注：作成されたスキル（.claude/skills/）は保持されます。
```

**ステップ2: 確認**
- 「すべてのSkillfyデータを削除してよろしいですか？」
- [はい、すべてリセット] [キャンセル]

**ステップ3: 結果**
```
✅ Skillfyデータがリセットされました

- パターン：すべて削除
- スキル：保持（.claude/skills/）

/skillfyで新しい記録を始めましょう。
```

</details>

## 使用例

Skillfyの使い方を学ぶための2つの一般的なシナリオです。

### 例1：コードスタイルの好み

最初から最後まで実際のシナリオを見ていきましょう。

#### 😤 問題の状況

ClaudeにReactコンポーネントの作成を依頼します：

```
> Buttonコンポーネントを作って
```

Claudeの応答：
```jsx
const Button = ({ label, onClick }) => {
  return <button onClick={onClick}>{label}</button>
}
```

**欲しかったのはTypeScriptインターフェース！** この問題が何度も発生します...

---

#### 📝 ステップ1：ミスマッチの記録

ミスマッチが発生した直後に`/skillfy`を実行：

```
状況：> Reactコンポーネント作成時
期待：> propsのTypeScriptインターフェース
指示：> コンポーネントのpropsには常にTypeScriptインターフェースを定義する

どうしますか？
> 1. スキルとして登録
```

結果：
```
✅ スキル作成完了：.claude/skills/creating-react-components/SKILL.md

🔄 このスキルを有効にするには、Claude Codeを再起動してください。
```

---

#### ✨ ステップ2：結果

**Claude Codeを再起動**した後、同じ質問：

```
> Buttonコンポーネントを作って
```

Claudeの応答：
```tsx
interface ButtonProps {
  label: string;
  onClick: () => void;
}

const Button = ({ label, onClick }: ButtonProps) => {
  return <button onClick={onClick}>{label}</button>
}
```

🎉 **Claudeが好みを学習し、自動的に適用するようになりました！**

---

### 例2：ワークフローの動作の好み

Claudeに自動で処理するか確認を求めるかを教える方法を学びます。

#### 😤 問題の状況

Claudeにコード品質のチェックを依頼します：

```
> lintとformatをチェックして
```

Claudeが問題を見つけて確認を求めます：
```
問題が見つかりました：

| チェック | 状態                           |
|----------|--------------------------------|
| ESLint   | ⚠️ 警告1件                     |
| Prettier | ❌ フォーマットが必要なファイル2件 |

これらの問題を修正しますか？
```

**そのまま直してほしいのに！** 毎回確認しないでほしい...

---

#### 📝 ステップ1：ミスマッチの記録

ミスマッチが発生した直後に`/skillfy`を実行：

```
状況：> lint/formatのチェック時
期待：> 確認なしで自動修正し、修正後に報告
指示：> 確認なしで修正し、修正後に報告する

どうしますか？
> 1. スキルとして登録
```

結果：
```
✅ スキル作成完了：.claude/skills/when-checking-lintformat/SKILL.md

🔄 このスキルを有効にするには、Claude Codeを再起動してください。
```

---

#### ✨ ステップ2：結果

**Claude Codeを再起動**した後、同じ質問：

```
> lintとformatをチェックして
```

Claudeの応答：
```
スキルで確認なしに修正するよう指示されています。問題を修正します。

✅ すべての問題を修正しました：

| チェック | 結果                                           |
|----------|------------------------------------------------|
| Prettier | ✅ 2ファイルをフォーマット（App.vue、HelloWorld.vue） |
| ESLint   | ✅ エラー0件、警告0件                          |

変更内容：
- src/App.vue — フォーマット修正
- src/components/HelloWorld.vue — フォーマット修正 + デフォルト値追加
```

🎉 **Claudeがワークフローの好みを学習し、確認なしで処理するようになりました！**

---

#### ⚠️ 注意：スキルの有効化

スキルは常に自動的にトリガーされるとは限りません。Claudeがスキルを適用しない場合：

1. **説明の改善** - スキルの`description`フィールドをより具体的に記述
2. **手動呼び出し** - 明示的に呼び出すことができます：
   ```
   > lintとformatをチェックして。スキル：when-checking-lintformat を使用
   ```
3. **スキルの読み込み確認** - `/skillfy help`を実行してスキルが認識されているか確認

---

## ベストプラクティス

推奨ワークフロー：

```
1. Claudeといつも通り作業
       ↓
2. ミスマッチを発見？ すぐに/skillfyを実行
       ↓
3. 具体的に：「コーディング時」より「Reactコンポーネント作成時」
       ↓
4. 明確な指示を記述：「常にTypeScriptインターフェースを使用」
       ↓
5. 新しいスキルを有効にするためにClaude Codeを再起動
```

**ヒント：**
- 📝 ミスマッチが**発生した直後**に記録 - コンテキストが重要です
- 🎯 状況を**具体的**に - 曖昧なパターンは役に立ちません
- ✍️ **命令形の指示**を記述 - 「常にXする」または「絶対にYしない」
- 🚀 スキル作成後は**Claude Codeを再起動**して読み込み

## 仕組み

1. **記録**：`/skillfy`でClaudeの出力が期待と異なる状況を記録
2. **保存または昇格**：後で確認するためにメモとして保存、またはすぐにスキルを作成
3. **レビュー**：`/skillfy review`で保存されたパターンをスキルに昇格
4. **適用**：スキルに昇格されると、Claudeが類似の状況で自動的に適用

## データ保存

| ファイル | 用途 |
|----------|------|
| `.claude/skillfy/patterns.db` | SQLite DB（`patterns`、`schema_version`テーブル） |
| `.claude/skills/*/SKILL.md` | 昇格されたスキル |

### スキルの命名規則

スキル作成時、名前は状況から自動生成されます：

| ルール | 例 |
|--------|-----|
| 小文字に変換 | "Creating Models" → "creating-models" |
| スペースをハイフンに置換 | "API endpoint" → "api-endpoint" |
| 特殊文字を削除 | "React (TSX)" → "react-tsx" |
| 最大50文字 | 超過時は切り詰め |
| 衝突処理 | サフィックスを追加：`-1`、`-2`など |

## セキュリティに関する考慮事項

### データプライバシー

- **patterns.dbには機密データが含まれる可能性があります**：データベースには記録した状況と期待が保存されます。含める情報に注意してください。
- **自動.gitignore**：initコマンドは誤ってコミットするのを防ぐため、自動的に`.claude/skillfy/`を`.gitignore`に追加します。
- **コミット前にスキルファイルを確認**：`.claude/skills/`内の生成されたスキルはgitignoreに含まれません。バージョン管理にコミットする前に、機密性のあるコンテキストがないか確認してください。
- **バックアップからの除外**：機密情報が含まれる場合は、クラウド同期サービスから`.claude/skillfy/`を除外することを検討してください。

### ファイル権限

初期化時にセキュリティ権限が**自動設定**されます：

| パス | 権限 | 説明 |
|------|------|------|
| `.claude/skillfy/` | `700`（rwx------） | 所有者のみ：読み取り、書き込み、実行 |
| `.claude/skills/` | `700`（rwx------） | 所有者のみ：読み取り、書き込み、実行 |
| `patterns.db` | `600`（rw-------） | 所有者のみ：読み取り、書き込み |

### 入力検証
- SQLインジェクションはクォートエスケープで防止
- パストラバーサルはスキル名生成で防止

## トラブルシューティング

### よくある問題

**「sqlite3が必要ですがインストールされていません」**
- macOS/Linux：sqlite3は通常プリインストールされています
- Windows：https://sqlite.org/download.html からインストール

**スキルが適用されない**
- スキルが正しく作成されたか確認（`/skillfy help`で状態確認）
- `.claude/skills/`にスキルファイルが存在するか確認
- 新しいスキルを読み込むために**Claude Codeを再起動**

## 要件

- Claude Code
- sqlite3 CLI（macOS/Linuxにプリインストール済み）
- SQLiteバージョン3.24.0以上（パフォーマンスと互換性の向上のため）
- `realpath`または`python3`（reviewコマンドのパス解決用；通常プリインストール済み）

## ライセンス

MIT
