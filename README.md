# HTML Parser WASM

Zigで実装された軽量なHTMLパーサーライブラリ。スクレイピング向けに最適化されています。

## 特徴

- 🚀 **軽量・高速** - Zigの性能を活かした効率的なパース処理
- 🎯 **スクレイピング最適化** - CSSセレクターによる要素検索
- 🛡️ **寛容なパース** - 壊れたHTMLも柔軟に処理
- 📦 **WASM対応準備** - WebAssemblyでの利用を想定

## 実装済み機能

### 基本機能
- ✅ HTMLトークナイザー（タグ、属性、テキスト、コメント）
- ✅ DOMツリー構築
- ✅ テキストコンテンツ抽出
- ✅ 属性の取得・設定

### セレクター機能
- ✅ タグセレクター（`div`, `p`, `a` など）
- ✅ クラスセレクター（`.classname`）
- ✅ IDセレクター（`#id`）
- ✅ 属性セレクター（`[href]`, `[type="text"]`）
- ✅ ユニバーサルセレクター（`*`）

## 使い方

### 基本的なパース

```zig
const std = @import("std");
const html_parser = @import("html_purser_wasm");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    const html = "<div class='container'><p>Hello World</p></div>";
    
    var parser = try html_parser.Parser.init(allocator, html);
    defer parser.deinit();
    
    const doc = try parser.parse();
}
```

### セレクターによる要素検索

```zig
// 単一要素の取得
if (try html_parser.querySelector(allocator, doc, "#main-title")) |element| {
    const text = try element.getTextContent(allocator);
    defer allocator.free(text);
    std.debug.print("Title: {s}\n", .{text});
}

// 複数要素のテキストを取得
var items = try html_parser.querySelectorAllText(allocator, doc, ".item");
defer {
    for (items.items) |text| {
        allocator.free(text);
    }
    items.deinit(allocator);
}

for (items.items) |text| {
    std.debug.print("Item: {s}\n", .{text});
}

// 属性値の一括取得
var links = try html_parser.querySelectorAttribute(allocator, doc, "a", "href");
defer links.deinit(allocator);

for (links.items) |href| {
    std.debug.print("Link: {s}\n", .{href});
}
```

## ビルドとテスト

```bash
# テストの実行
zig build test

# デモの実行
zig build run
```

## プロジェクト構造

```
src/
├── main.zig         # デモアプリケーション
├── root.zig         # モジュールエクスポート
├── tokenizer.zig    # HTMLトークナイザー
├── parser.zig       # DOMパーサー
├── node.zig         # DOMノード定義
├── selector.zig     # CSSセレクター実装
└── query.zig        # クエリエンジン
```

## API リファレンス

### Parser

```zig
pub fn Parser.init(allocator: Allocator, html: []const u8) !Parser
pub fn Parser.parse(self: *Parser) !*Node
pub fn Parser.deinit(self: *Parser) void
```

### Node

```zig
pub fn Node.createElement(allocator: Allocator, tag_name: []const u8) !*Node
pub fn Node.createText(allocator: Allocator, text: []const u8) !*Node
pub fn Node.appendChild(self: *Node, child: *Node) !void
pub fn Node.setAttribute(self: *Node, name: []const u8, value: []const u8) !void
pub fn Node.getAttribute(self: *Node, name: []const u8) ?[]const u8
pub fn Node.getTextContent(self: *Node, allocator: Allocator) ![]const u8
```

### Query

```zig
pub fn querySelector(allocator: Allocator, root: *Node, selector: []const u8) !?*Node
pub fn querySelectorAll(allocator: Allocator, root: *Node, selector: []const u8) !ArrayList(*Node)
pub fn querySelectorAllText(allocator: Allocator, root: *Node, selector: []const u8) !ArrayList([]const u8)
pub fn querySelectorAttribute(allocator: Allocator, root: *Node, selector: []const u8, attr_name: []const u8) !ArrayList([]const u8)
```

## 今後の実装予定

- [ ] 子孫セレクター（`div p`, `ul > li`）
- [ ] 疑似クラス（`:first-child`, `:nth-child(n)`）
- [ ] 複合セレクター（`div.class#id`）
- [ ] WASM エクスポート関数
- [ ] JavaScript バインディング
- [ ] ストリーミングパース（大容量HTML対応）
- [ ] インデックス作成（高速検索）

## ライセンス

MIT License

## 開発環境

- Zig 0.15.2 以上
