// Streaming parser example for Deno
import { StreamingHTMLParser } from "./main.ts";

const parser = new StreamingHTMLParser();

// Load WASM file
const wasmBytes = await Deno.readFile("./zig-out/wasm/html_purser_wasm.wasm");
await parser.init(wasmBytes);

console.log("=== Streaming HTML Parser Demo (Deno) ===\n");

// Register selectors
parser.addSelector(".product-title");
parser.addSelector(".price");
parser.addSelector(".rating");

console.log("Registered selectors:");
console.log("  - .product-title");
console.log("  - .price");
console.log("  - .rating\n");

// Simulate streaming chunks (e.g., from network)
const chunks = [
  '<!DOCTYPE html><html><body>',
  '<div class="product">',
  '  <h2 class="product-title">Gaming Laptop</h2>',
  '  <span class="price">$1,299.99</span>',
  '  <div class="rating">⭐⭐⭐⭐⭐</div>',
  '</div>',
  '<div class="product">',
  '  <h2 class="product-title">Mechanical Keyboard</h2>',
  '  <span class="price">$149.99</span>',
  '  <div class="rating">⭐⭐⭐⭐</div>',
  '</div>',
  '<div class="product">',
  '  <h2 class="product-title">Gaming Mouse</h2>',
  '  <span class="price">$79.99</span>',
  '  <div class="rating">⭐⭐⭐⭐⭐</div>',
  '</div>',
  '</body></html>',
];

console.log("Processing chunks...");
for (const [index, chunk] of chunks.entries()) {
  console.log(`  Chunk ${index + 1}: ${chunk.length} bytes`);
  parser.feed(chunk);
}

parser.finish();
console.log("\n✅ Parsing complete!\n");

// Get results
console.log("Product Titles:");
const titles = parser.getMatchesText(".product-title");
titles.forEach((title, i) => {
  console.log(`  ${i + 1}. ${title.trim()}`);
});

console.log("\nPrices:");
const prices = parser.getMatchesText(".price");
prices.forEach((price, i) => {
  console.log(`  ${i + 1}. ${price.trim()}`);
});

console.log("\nRatings:");
const ratings = parser.getMatchesText(".rating");
ratings.forEach((rating, i) => {
  console.log(`  ${i + 1}. ${rating.trim()}`);
});

console.log("\n=== Summary ===");
console.log(`Total products found: ${titles.length}`);
console.log(`Total chunks processed: ${chunks.length}`);
console.log(`Memory efficient: Only matched elements kept in memory`);

// Cleanup
parser.cleanup();

console.log("\n✅ Demo completed successfully!");
