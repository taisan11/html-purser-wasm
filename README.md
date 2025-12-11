# HTML Parser WASM

Zigで実装された軽量なHTMLパーサーライブラリ。
スクレイピング向けでサーバーサイドJS/TSでの利用を想定しています。

## 特徴

- 🚀 **軽量・高速** - Zigの性能を活かした効率的なパース処理
- 🎯 **スクレイピング最適化** - document APIを意識しました!!
- 🛡️ **寛容なパース** - 壊れたHTMLも柔軟に処理
- 📦 **WASM対応** - WASMが動く所ならどこへでも
- 🔧 **ゼロ依存** - とっても軽量です。

## 実装済み機能

セレクターは下記の物を使えます、制限事項も一緒にご覧ください。
- タグセレクター（`div`, `p`, `a` など）
- クラスセレクター（`.classname`）
- IDセレクター（`#id`）
- 属性セレクター（`[href]`, `[type="text"]`）
- ユニバーサルセレクター（`*`）

ストリーミングパースに対応してい為、そちらを使用するとメモリ効率等が良くなります。

## インストール

### WASMモジュールのビルド

```bash
zig build wasm
```

ビルドされたWASMファイルは `zig-out/wasm/html_purser_wasm.wasm` に出力されます。

## 使い方

WASMファイルの取得方法は環境に応じてユーザーが選択できます。
下記ではDenoでの利用の例を記します。

### 通常パース（DOM操作が必要な場合）

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

### ストリーミングパース（大容量HTML・メモリ効率重視）

```typescript
import { StreamingHTMLParser } from "./main.ts";

const parser = new StreamingHTMLParser();

const wasmBytes = await Deno.readFile("./zig-out/wasm/html_purser_wasm.wasm");
await parser.init(wasmBytes);

// セレクター登録
parser.addSelector(".price");
parser.addSelector(".title");

// チャンクごとに処理
for await (const chunk of readHTMLStream(url)) {
  parser.feed(chunk);
}
parser.finish();

// 結果取得
const prices = parser.getMatchesText(".price");
console.log(prices); // ["$99", "$149", "$199"]

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

### Zig ネイティブ（通常パース）

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
}
```

### Zig ストリーミングパース（大容量HTML向け）

```zig
const std = @import("std");
const html_parser = @import("html_purser_wasm");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    var parser = html_parser.StreamingParser.init(allocator);
    defer parser.deinit();
    
    // 抽出したいセレクターを登録
    try parser.addSelector(".price");
    try parser.addSelector(".title");
    
    // チャンクごとに処理（ネットワークストリーミングなど）
    try parser.feed("<div class=\"product\">");
    try parser.feed("<h2 class=\"title\">Product</h2>");
    try parser.feed("<span class=\"price\">$99</span>");
    try parser.feed("</div>");
    
    try parser.finish();
    
    // マッチした要素のみ取得
    if (parser.getMatches(".price")) |prices| {
        for (prices) |price| {
            std.debug.print("Price: {s}\n", .{price.text});
        }
    }
}
```

## 制限事項

- WASMビルドは固定サイズのバッファ（1MB）を使用
- 非常に大きなHTMLファイル（>1MB）はストリーミングパースを推奨
- 複雑なCSSセレクター（擬似クラス等）は未実装
- ストリーミングパースはDOM操作不可（抽出専用）

## ビルドとテスト

```bash
# ネイティブビルドとテスト
zig build test

# ネイティブデモの実行
zig build run                    # 通常パーサーデモ
zig build demo-streaming         # ストリーミングパーサーデモ

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
├── main.zig                # ネイティブデモアプリケーション
├── streaming_demo.zig      # ストリーミングデモ
├── wasm.zig                # WASM FFIインターフェース
├── root.zig                # モジュールエクスポート
├── tokenizer.zig           # HTMLトークナイザー
├── parser.zig              # DOMパーサー
├── streaming.zig           # ストリーミングパーサー
├── node.zig                # DOMノード定義
├── selector.zig            # CSSセレクター実装
└── query.zig               # クエリエンジン

main.ts                     # TypeScript WASMラッパー（通常・ストリーミング両対応）
example-deno.ts             # Deno通常パース例
example-streaming-deno.ts   # Denoストリーミング例
example-node.js             # Node.js使用例
example-browser.html        # ブラウザ通常パース例
example-streaming-browser.html # ブラウザストリーミング例
build.zig                   # ビルド設定
```

## API リファレンス

### TypeScript API

#### 通常パーサー

```typescript
class HTMLParser {
  async init(wasmBytes: BufferSource): Promise<void>
  parse(html: string): boolean
  querySelector(selector: string): string | null
  querySelectorAll(selector: string): string[]
  querySelectorAttribute(selector: string, attribute: string): string[]
  cleanup(): void
}
```

#### ストリーミングパーサー

```typescript
interface StreamMatch {
  text: string;
  attributes: Map<string, string>;
}

class StreamingHTMLParser {
  async init(wasmBytes: BufferSource): Promise<void>
  
  // セレクターを事前登録
  addSelector(selector: string): void
  
  // チャンクを段階的に処理
  feed(chunk: string): void
  
  // パース完了
  finish(): void
  
  // マッチした要素を取得
  getMatches(selector: string): StreamMatch[]
  getMatchesText(selector: string): string[]
  getMatchAttribute(selector: string, index: number, attributeName: string): string | null
  
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

## RoadMap!!

- [ ] 子孫セレクター（`div p`, `ul > li`）
- [ ] 疑似クラス（`:first-child`, `:nth-child(n)`）
- [ ] 複合セレクター（`div.class#id`）
- [ ] インデックス作成（高速検索）
- [ ] ブラウザ向けES Modules対応

## 開発環境

- Zig 0.15.2 以上
- Deno 2.0 以上（WASM実行用）

