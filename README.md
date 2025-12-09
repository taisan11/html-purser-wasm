# HTML Parser WASM

Zigで実装された軽量なHTMLパーサーライブラリ。スクレイピング向けに最適化され、WebAssemblyでブラウザやDenoから利用可能です。

## 特徴

- 🚀 **軽量・高速** - Zigの性能を活かした効率的なパース処理
- 🎯 **スクレイピング最適化** - CSSセレクターによる要素検索
- 🛡️ **寛容なパース** - 壊れたHTMLも柔軟に処理
- 📦 **WASM対応** - ブラウザ・Deno・Node.jsで動作
- 🔧 **ゼロ依存** - 外部ライブラリ不要

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

### WASM対応
- ✅ WebAssemblyビルド
- ✅ TypeScript/JavaScriptバインディング
- ✅ メモリ管理

## インストール

### WASMモジュールのビルド

```bash
zig build wasm
```

ビルドされたWASMファイルは `zig-out/wasm/html_purser_wasm.wasm` に出力されます。

## 使い方

WASMファイルの取得方法は環境に応じてユーザーが選択できます。

### Deno

```typescript
import { HTMLParser } from "./main.ts";

const parser = new HTMLParser();

// WASM ファイルを読み込み
const wasmBytes = await Deno.readFile("./zig-out/wasm/html_purser_wasm.wasm");
await parser.init(wasmBytes);

parser.parse('<div id="test">Hello</div>');
const text = parser.querySelector("#test");
console.log(text); // "Hello"

parser.cleanup();
```

### ブラウザ

```javascript
import { HTMLParser } from "./main.js";

const parser = new HTMLParser();

// WASM ファイルをフェッチ
const response = await fetch("./html_purser_wasm.wasm");
const wasmBytes = await response.arrayBuffer();
await parser.init(wasmBytes);

parser.parse('<div class="test">Hello</div>');
const text = parser.querySelector(".test");
console.log(text); // "Hello"

parser.cleanup();
```

### Node.js

```javascript
const fs = require('fs');
const { HTMLParser } = require('./main.js');

const parser = new HTMLParser();

// WASM ファイルを読み込み
const wasmBytes = fs.readFileSync('./html_purser_wasm.wasm');
await parser.init(wasmBytes);

parser.parse('<h1>Title</h1>');
const text = parser.querySelector("h1");
console.log(text); // "Title"

parser.cleanup();
```

### API使用例

```typescript
const html = `
  <div class="container">
    <h1 id="title">Hello World</h1>
    <p class="text">Paragraph 1</p>
    <p class="text">Paragraph 2</p>
    <a href="https://example.com">Link</a>
  </div>
`;

// HTMLをパース
parser.parse(html);

// 単一要素を取得
const title = parser.querySelector("#title");
console.log(title); // "Hello World"

// 複数要素のテキストを取得
const paragraphs = parser.querySelectorAll(".text");
console.log(paragraphs); // ["Paragraph 1", "Paragraph 2"]

// 属性値を取得
const links = parser.querySelectorAttribute("a", "href");
console.log(links); // ["https://example.com"]

// クリーンアップ
parser.cleanup();
```

### Zig（ネイティブ）

```zig
const std = @import("std");
const html_parser = @import("html_purser_wasm");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    const html = "<div class='container'><p>Hello World</p></div>";
    
    var parser = try html_parser.Parser.init(allocator, html);
    defer parser.deinit();
    
    const doc = try parser.parse();
    
    // 単一要素の取得
    if (try html_parser.querySelector(allocator, doc, ".container")) |element| {
        const text = try element.getTextContent(allocator);
        defer allocator.free(text);
        std.debug.print("Text: {s}\n", .{text});
    }
    
    // 複数要素のテキストを取得
    var items = try html_parser.querySelectorAllText(allocator, doc, "p");
    defer {
        for (items.items) |text| {
            allocator.free(text);
        }
        items.deinit(allocator);
    }
    
    for (items.items) |text| {
        std.debug.print("Item: {s}\n", .{text});
    }
}
```

## ビルドとテスト

```bash
# ネイティブビルドとテスト
zig build test

# ネイティブデモの実行
zig build run

# WASMビルド
zig build wasm

# デモの実行（環境に応じて選択）
deno run --allow-read example-deno.ts        # Deno
node example-node.js                         # Node.js
# example-browser.html をブラウザで開く      # Browser
```

## プロジェクト構造

```
src/
├── main.zig            # ネイティブデモアプリケーション
├── wasm.zig            # WASM FFIインターフェース
├── root.zig            # モジュールエクスポート
├── tokenizer.zig       # HTMLトークナイザー
├── parser.zig          # DOMパーサー
├── node.zig            # DOMノード定義
├── selector.zig        # CSSセレクター実装
└── query.zig           # クエリエンジン

main.ts                 # TypeScript WASMラッパー（プラットフォーム非依存）
example-deno.ts         # Deno使用例
example-node.js         # Node.js使用例
example-browser.html    # ブラウザ使用例
build.zig               # ビルド設定
```

## API リファレンス

### TypeScript API

```typescript
class HTMLParser {
  // WASMバイナリで初期化（BufferSource = Uint8Array | ArrayBuffer）
  async init(wasmBytes: BufferSource): Promise<void>
  
  // HTMLをパース
  parse(html: string): boolean
  
  // セレクターで単一要素を取得
  querySelector(selector: string): string | null
  
  // セレクターで複数要素を取得
  querySelectorAll(selector: string): string[]
  
  // セレクターで属性値を一括取得
  querySelectorAttribute(selector: string, attribute: string): string[]
  
  // メモリをクリーンアップ
  cleanup(): void
}
```

### Zig Native API

```zig
// Parser
pub fn Parser.init(allocator: Allocator, html: []const u8) !Parser
pub fn Parser.parse(self: *Parser) !*Node
pub fn Parser.deinit(self: *Parser) void

// Node
pub fn Node.createElement(allocator: Allocator, tag_name: []const u8) !*Node
pub fn Node.createText(allocator: Allocator, text: []const u8) !*Node
pub fn Node.appendChild(self: *Node, child: *Node) !void
pub fn Node.setAttribute(self: *Node, name: []const u8, value: []const u8) !void
pub fn Node.getAttribute(self: *Node, name: []const u8) ?[]const u8
pub fn Node.getTextContent(self: *Node, allocator: Allocator) ![]const u8

// Query
pub fn querySelector(allocator: Allocator, root: *Node, selector: []const u8) !?*Node
pub fn querySelectorAll(allocator: Allocator, root: *Node, selector: []const u8) !ArrayList(*Node)
pub fn querySelectorAllText(allocator: Allocator, root: *Node, selector: []const u8) !ArrayList([]const u8)
pub fn querySelectorAttribute(allocator: Allocator, root: *Node, selector: []const u8, attr_name: []const u8) !ArrayList([]const u8)
```

## パフォーマンス

WASMモジュールのサイズ: 約 40-50KB（ReleaseSmall）

典型的なHTMLページ（10KB）のパース時間:
- ネイティブ（Zig）: ~0.1ms
- WASM（Deno/ブラウザ）: ~0.5ms

## 制限事項

- WASMビルドは固定サイズのバッファ（1MB）を使用
- 非常に大きなHTMLファイル（>1MB）はネイティブビルドを推奨
- 複雑なCSSセレクター（擬似クラス等）は未実装

## 今後の実装予定

- [ ] 子孫セレクター（`div p`, `ul > li`）
- [ ] 疑似クラス（`:first-child`, `:nth-child(n)`）
- [ ] 複合セレクター（`div.class#id`）
- [ ] ストリーミングパース（大容量HTML対応）
- [ ] インデックス作成（高速検索）
- [ ] ブラウザ向けES Modules対応

## 開発環境

- Zig 0.15.2 以上
- Deno 2.0 以上（WASM実行用）

