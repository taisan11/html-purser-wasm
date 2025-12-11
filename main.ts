// HTML Parser WASM TypeScript Wrapper

interface WASMExports {
  memory: WebAssembly.Memory;
  alloc: (size: number) => number;
  dealloc: (ptr: number, size: number) => void;
  parse: (html_ptr: number, html_len: number) => number;
  querySelector: (selector_ptr: number, selector_len: number) => number;
  getResultText: () => number;
  getResultTextLen: () => number;
  querySelectorAll: (selector_ptr: number, selector_len: number) => number;
  querySelectorAllText: (selector_ptr: number, selector_len: number) => number;
  getTextAt: (index: number) => number;
  getTextLenAt: (index: number) => number;
  querySelectorAttribute: (
    selector_ptr: number,
    selector_len: number,
    attr_ptr: number,
    attr_len: number,
  ) => number;
  cleanup: () => void;
  
  // Streaming API
  streamingInit: () => number;
  streamingAddSelector: (selector_ptr: number, selector_len: number) => number;
  streamingFeed: (chunk_ptr: number, chunk_len: number) => number;
  streamingFinish: () => number;
  streamingGetMatchCount: (selector_ptr: number, selector_len: number) => number;
  streamingGetMatchText: (
    selector_ptr: number,
    selector_len: number,
    index: number,
  ) => number;
  streamingGetMatchTextLen: (
    selector_ptr: number,
    selector_len: number,
    index: number,
  ) => number;
  streamingGetMatchAttribute: (
    selector_ptr: number,
    selector_len: number,
    index: number,
    attr_ptr: number,
    attr_len: number,
  ) => number;
  streamingGetMatchAttributeLen: (
    selector_ptr: number,
    selector_len: number,
    index: number,
    attr_ptr: number,
    attr_len: number,
  ) => number;
  streamingCleanup: () => void;
}

export class HTMLParser {
  private wasm: WASMExports | null = null;
  private textEncoder = new TextEncoder();
  private textDecoder = new TextDecoder();

  /**
   * Initialize the WASM module with WebAssembly bytes
   * @param wasmBytes - The WASM binary (Uint8Array or ArrayBuffer)
   * @example
   * // Browser
   * const response = await fetch('html_purser_wasm.wasm');
   * const wasmBytes = await response.arrayBuffer();
   * await parser.init(wasmBytes);
   * 
   * // Deno
   * const wasmBytes = await Deno.readFile('./zig-out/wasm/html_purser_wasm.wasm');
   * await parser.init(wasmBytes);
   * 
   * // Node.js
   * const fs = require('fs');
   * const wasmBytes = fs.readFileSync('./html_purser_wasm.wasm');
   * await parser.init(wasmBytes);
   */
  async init(wasmBytes: BufferSource) {
    const wasmModule = await WebAssembly.instantiate(wasmBytes, {
      env: {},
    });
    this.wasm = wasmModule.instance.exports as unknown as WASMExports;
  }

  private writeString(str: string): { ptr: number; len: number } {
    if (!this.wasm) throw new Error("WASM not initialized");
    
    const encoded = this.textEncoder.encode(str);
    const ptr = this.wasm.alloc(encoded.length);
    if (!ptr) throw new Error("Memory allocation failed");
    
    const memory = new Uint8Array(this.wasm.memory.buffer);
    memory.set(encoded, ptr);
    
    return { ptr, len: encoded.length };
  }

  private readString(ptr: number, len: number): string {
    if (!this.wasm) throw new Error("WASM not initialized");
    
    const memory = new Uint8Array(this.wasm.memory.buffer);
    const bytes = memory.slice(ptr, ptr + len);
    return this.textDecoder.decode(bytes);
  }

  parse(html: string): boolean {
    if (!this.wasm) throw new Error("WASM not initialized");
    
    const { ptr, len } = this.writeString(html);
    try {
      return this.wasm.parse(ptr, len) !== 0;
    } finally {
      this.wasm.dealloc(ptr, len);
    }
  }

  querySelector(selector: string): string | null {
    if (!this.wasm) throw new Error("WASM not initialized");
    
    const { ptr, len } = this.writeString(selector);
    try {
      const found = this.wasm.querySelector(ptr, len);
      if (!found) return null;
      
      const textPtr = this.wasm.getResultText();
      if (!textPtr) return null;
      
      const textLen = this.wasm.getResultTextLen();
      return this.readString(textPtr, textLen);
    } finally {
      this.wasm.dealloc(ptr, len);
    }
  }

  querySelectorAll(selector: string): string[] {
    if (!this.wasm) throw new Error("WASM not initialized");
    
    const { ptr, len } = this.writeString(selector);
    try {
      const count = this.wasm.querySelectorAllText(ptr, len);
      const results: string[] = [];
      
      for (let i = 0; i < count; i++) {
        const textPtr = this.wasm.getTextAt(i);
        if (textPtr) {
          const textLen = this.wasm.getTextLenAt(i);
          results.push(this.readString(textPtr, textLen));
        }
      }
      
      return results;
    } finally {
      this.wasm.dealloc(ptr, len);
    }
  }

  querySelectorAttribute(selector: string, attribute: string): string[] {
    if (!this.wasm) throw new Error("WASM not initialized");
    
    const sel = this.writeString(selector);
    const attr = this.writeString(attribute);
    
    try {
      const count = this.wasm.querySelectorAttribute(
        sel.ptr,
        sel.len,
        attr.ptr,
        attr.len,
      );
      const results: string[] = [];
      
      for (let i = 0; i < count; i++) {
        const textPtr = this.wasm.getTextAt(i);
        if (textPtr) {
          const textLen = this.wasm.getTextLenAt(i);
          results.push(this.readString(textPtr, textLen));
        }
      }
      
      return results;
    } finally {
      this.wasm.dealloc(sel.ptr, sel.len);
      this.wasm.dealloc(attr.ptr, attr.len);
    }
  }

  cleanup() {
    if (!this.wasm) return;
    this.wasm.cleanup();
  }
}

export interface StreamMatch {
  text: string;
  attributes: Map<string, string>;
}

export class StreamingHTMLParser {
  private wasm: WASMExports | null = null;
  private textEncoder = new TextEncoder();
  private textDecoder = new TextDecoder();
  private selectors: string[] = [];

  async init(wasmBytes: BufferSource) {
    const wasmModule = await WebAssembly.instantiate(wasmBytes, {
      env: {},
    });
    this.wasm = wasmModule.instance.exports as unknown as WASMExports;
    
    const success = this.wasm.streamingInit();
    if (!success) {
      throw new Error("Failed to initialize streaming parser");
    }
  }

  private writeString(str: string): { ptr: number; len: number } {
    if (!this.wasm) throw new Error("WASM not initialized");
    
    const encoded = this.textEncoder.encode(str);
    const ptr = this.wasm.alloc(encoded.length);
    if (!ptr) throw new Error("Memory allocation failed");
    
    const memory = new Uint8Array(this.wasm.memory.buffer);
    memory.set(encoded, ptr);
    
    return { ptr, len: encoded.length };
  }

  private readString(ptr: number, len: number): string {
    if (!this.wasm) throw new Error("WASM not initialized");
    
    const memory = new Uint8Array(this.wasm.memory.buffer);
    const bytes = memory.slice(ptr, ptr + len);
    return this.textDecoder.decode(bytes);
  }

  addSelector(selector: string): void {
    if (!this.wasm) throw new Error("WASM not initialized");
    
    this.selectors.push(selector);
    const { ptr, len } = this.writeString(selector);
    try {
      const success = this.wasm.streamingAddSelector(ptr, len);
      if (!success) {
        throw new Error(`Failed to add selector: ${selector}`);
      }
    } finally {
      this.wasm.dealloc(ptr, len);
    }
  }

  feed(chunk: string): void {
    if (!this.wasm) throw new Error("WASM not initialized");
    
    const { ptr, len } = this.writeString(chunk);
    try {
      const success = this.wasm.streamingFeed(ptr, len);
      if (!success) {
        throw new Error("Failed to feed chunk");
      }
    } finally {
      this.wasm.dealloc(ptr, len);
    }
  }

  finish(): void {
    if (!this.wasm) throw new Error("WASM not initialized");
    
    const success = this.wasm.streamingFinish();
    if (!success) {
      throw new Error("Failed to finish parsing");
    }
  }

  getMatches(selector: string): StreamMatch[] {
    if (!this.wasm) throw new Error("WASM not initialized");
    
    const sel = this.writeString(selector);
    try {
      const count = this.wasm.streamingGetMatchCount(sel.ptr, sel.len);
      const results: StreamMatch[] = [];
      
      for (let i = 0; i < count; i++) {
        const textPtr = this.wasm.streamingGetMatchText(sel.ptr, sel.len, i);
        if (!textPtr) continue;
        
        const textLen = this.wasm.streamingGetMatchTextLen(sel.ptr, sel.len, i);
        const text = this.readString(textPtr, textLen);
        
        const attributes = new Map<string, string>();
        results.push({ text, attributes });
      }
      
      return results;
    } finally {
      this.wasm.dealloc(sel.ptr, sel.len);
    }
  }

  getMatchesText(selector: string): string[] {
    return this.getMatches(selector).map(m => m.text);
  }

  getMatchAttribute(selector: string, index: number, attributeName: string): string | null {
    if (!this.wasm) throw new Error("WASM not initialized");
    
    const sel = this.writeString(selector);
    const attr = this.writeString(attributeName);
    
    try {
      const attrPtr = this.wasm.streamingGetMatchAttribute(
        sel.ptr,
        sel.len,
        index,
        attr.ptr,
        attr.len,
      );
      
      if (!attrPtr) return null;
      
      const attrLen = this.wasm.streamingGetMatchAttributeLen(
        sel.ptr,
        sel.len,
        index,
        attr.ptr,
        attr.len,
      );
      
      return this.readString(attrPtr, attrLen);
    } finally {
      this.wasm.dealloc(sel.ptr, sel.len);
      this.wasm.dealloc(attr.ptr, attr.len);
    }
  }

  cleanup() {
    if (!this.wasm) return;
    this.wasm.streamingCleanup();
  }
}


