// Deno example usage
import { HTMLParser } from "./main.ts";

const parser = new HTMLParser();

// Load WASM file (Deno-specific)
const wasmBytes = await Deno.readFile("./zig-out/wasm/html_purser_wasm.wasm");
await parser.init(wasmBytes);

const html = `
  <!DOCTYPE html>
  <html>
  <head>
    <title>Test Page</title>
  </head>
  <body>
    <div class="container">
      <h1 id="main-title">HTML Parser Demo</h1>
      <p class="intro">This is a <strong>test</strong> paragraph.</p>
      <ul class="items">
        <li class="item">Item 1</li>
        <li class="item">Item 2</li>
        <li class="item">Item 3</li>
      </ul>
      <a href="https://example.com">Example Link</a>
      <a href="https://test.com">Test Link</a>
    </div>
  </body>
  </html>
`;

console.log("=== HTML Parser WASM Demo (Deno) ===\n");

// Parse HTML
if (!parser.parse(html)) {
  console.error("Failed to parse HTML");
  Deno.exit(1);
}

// querySelector - single element
const title = parser.querySelector("#main-title");
console.log("Title:", title?.trim());

// querySelectorAll - multiple elements
console.log("\nAll items:");
const items = parser.querySelectorAll(".item");
items.forEach((item, i) => {
  console.log(`  ${i + 1}. ${item.trim()}`);
});

// querySelectorAttribute - get attributes
console.log("\nAll links:");
const links = parser.querySelectorAttribute("a", "href");
links.forEach((link) => {
  console.log(`  - ${link}`);
});

// Tag selector
console.log("\nAll paragraphs:");
const paragraphs = parser.querySelectorAll("p");
paragraphs.forEach((p) => {
  console.log(`  ${p.trim()}`);
});

// Cleanup
parser.cleanup();

console.log("\n✅ Demo completed successfully!");
