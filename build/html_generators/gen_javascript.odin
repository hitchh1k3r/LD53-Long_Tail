package html_generators

import "core:os"
import "core:encoding/base64"

import "project:platform/wasm/mem"

import "build:beard"

WebGL_Version :: enum {
  No_WebGL,
  WebGL_1,
  WebGL_2,
}

gen_javascript :: proc(wasm_path : string, webgl_version : WebGL_Version, output_path : string) {
  PROFILE_START("read_wasm()")
  wasm_file, _ := os.read_entire_file(wasm_path)
  PROFILE_END()
  PROFILE_START("to_base64()")
  base64_wasm := base64.encode(wasm_file)
  PROFILE_END()
  delete(wasm_file)
  defer delete(base64_wasm)
  beard_data := beard.Map{
    "webgl_1" = (webgl_version != .No_WebGL),
    "webgl_2" = (webgl_version == .WebGL_2),
    "base64_wasm" = base64_wasm,
  }
  js_src := beard.process(TEMPLATE_JAVASCRIPT_FILE, beard_data)
  PROFILE_START("write_js()")
  os.write_entire_file(output_path, transmute([]u8)(js_src))
  PROFILE_END()
}


@(private="file")
TEMPLATE_JAVASCRIPT_FILE :: `"use strict";
(async function() {
  function getElement(name) {
    if (name) {
      return document.getElementById(name);
    }
    return undefined;
  }

  class WasmMemoryInterface {
    constructor() {
      this.memory = null;
      this.exports = null;
      this.listenerMap = {};
    }

    setMemory(memory) {
      this.memory = memory;
    }

    setExports(exports) {
      this.exports = exports;
    }

    get mem() {
      return new DataView(this.memory.buffer);
    }

    loadF32Array(addr, len) {
      let array = new Float32Array(this.memory.buffer, addr, len);
      return array;
    }
    loadF64Array(addr, len) {
      let array = new Float64Array(this.memory.buffer, addr, len);
      return array;
    }
    loadU32Array(addr, len) {
      let array = new Uint32Array(this.memory.buffer, addr, len);
      return array;
    }
    loadI32Array(addr, len) {
      let array = new Int32Array(this.memory.buffer, addr, len);
      return array;
    }

    loadU8(addr) { return this.mem.getUint8  (addr, true); }
    loadI8(addr) { return this.mem.getInt8   (addr, true); }
    loadU16(addr) { return this.mem.getUint16 (addr, true); }
    loadI16(addr) { return this.mem.getInt16  (addr, true); }
    loadU32(addr) { return this.mem.getUint32 (addr, true); }
    loadI32(addr) { return this.mem.getInt32  (addr, true); }
    loadU64(addr) {
      const lo = this.mem.getUint32(addr + 0, true);
      const hi = this.mem.getUint32(addr + 4, true);
      return lo + hi*4294967296;
    };
    loadI64(addr) {
      // TODO(bill): loadI64 correctly
      const lo = this.mem.getUint32(addr + 0, true);
      const hi = this.mem.getUint32(addr + 4, true);
      return lo + hi*4294967296;
    };
    loadF32(addr)  { return this.mem.getFloat32(addr, true); }
    loadF64(addr)  { return this.mem.getFloat64(addr, true); }
    loadInt(addr)  { return this.mem.getInt32  (addr, true); }
    loadUint(addr) { return this.mem.getUint32 (addr, true); }

    loadPtr(addr) { return this.loadUint(addr); }

    loadBytes(ptr, len) {
      return new Uint8Array(this.memory.buffer, ptr, len);
    }

    loadString(ptr, len) {
      const bytes = this.loadBytes(ptr, len);
      return new TextDecoder("utf-8").decode(bytes);
    }

    storeU8(addr, value)  { this.mem.setUint8  (addr, value, true); }
    storeI8(addr, value)  { this.mem.setInt8   (addr, value, true); }
    storeU16(addr, value) { this.mem.setUint16 (addr, value, true); }
    storeI16(addr, value) { this.mem.setInt16  (addr, value, true); }
    storeU32(addr, value) { this.mem.setUint32 (addr, value, true); }
    storeI32(addr, value) { this.mem.setInt32  (addr, value, true); }
    storeU64(addr, value) {
      this.mem.setUint32(addr + 0, value, true);
      this.mem.setUint32(addr + 4, Math.floor(value / 4294967296), true);
    }
    storeI64(addr, value) {
      // TODO(bill): storeI64 correctly
      this.mem.setUint32(addr + 0, value, true);
      this.mem.setUint32(addr + 4, Math.floor(value / 4294967296), true);
    }
    storeF32(addr, value)  { this.mem.setFloat32(addr, value, true); }
    storeF64(addr, value)  { this.mem.setFloat64(addr, value, true); }
    storeInt(addr, value)  { this.mem.setInt32  (addr, value, true); }
    storeUint(addr, value) { this.mem.setUint32 (addr, value, true); }
  };
  {{#webgl_1}}

    class WebGLInterface {
      constructor(wasmMemoryInterface) {
        this.wasmMemoryInterface = wasmMemoryInterface;
        this.ctxElement         = null;
        this.ctx                = null;
        this.ctxVersion         = 1.0;
        this.counter            = 1;
        this.lastError          = 0;
        this.buffers            = [];
        this.mappedBuffers      = {};
        this.programs           = [];
        this.framebuffers       = [];
        this.renderbuffers      = [];
        this.textures           = [];
        this.uniforms           = [];
        this.shaders            = [];
        this.vaos               = [];
        this.contexts           = [];
        this.currentContext     = null;
        this.offscreenCanvases  = {};
        this.timerQueriesEXT    = [];
        this.queries            = [];
        this.samplers           = [];
        this.transformFeedbacks = [];
        this.syncs              = [];
        this.programInfos       = {};
      }

      get mem() {
        return this.wasmMemoryInterface
      }

      setCurrentContext(element, contextSettings) {
        if (!element) {
          return false;
        }
        if (this.ctxElement == element) {
          return true;
        }

        contextSettings = contextSettings ?? {};
        this.ctx = element.getContext("webgl2", contextSettings) || element.getContext("webgl", contextSettings);
        if (!this.ctx) {
          return false;
        }
        window.gl = this.ctx;
        this.ctxElement = element;
        if (this.ctx.getParameter(0x1F02).indexOf("WebGL 2.0") !== -1) {
          this.ctxVersion = 2.0;
        } else {
          this.ctxVersion = 1.0;
        }
        return true;
      }

      assertWebGL2() {
        if (this.ctxVersion < 2) {
          throw new Error("WebGL2 procedure called in a canvas without a WebGL2 context");
        }
      }

      getNewId(table) {
        for (var ret = this.counter++, i = table.length; i < ret; i++) {
          table[i] = null;
        }
        return ret;
      }

      recordError(errorCode) {
        this.lastError || (this.lastError = errorCode);
      }

      populateUniformTable(program) {
        let p = this.programs[program];
        this.programInfos[program] = {
          uniforms: {},
          maxUniformLength: 0,
          maxAttributeLength: -1,
          maxUniformBlockNameLength: -1,
        };
        for (let ptable = this.programInfos[program], utable = ptable.uniforms, numUniforms = this.ctx.getProgramParameter(p, this.ctx.ACTIVE_UNIFORMS), i = 0; i < numUniforms; ++i) {
          let u = this.ctx.getActiveUniform(p, i);
          let name = u.name;
          if (ptable.maxUniformLength = Math.max(ptable.maxUniformLength, name.length + 1), name.indexOf("]", name.length - 1) !== -1) {
            name = name.slice(0, name.lastIndexOf("["));
          }
          let loc = this.ctx.getUniformLocation(p, name);
          if (loc !== null) {
            let id = this.getNewId(this.uniforms);
            utable[name] = [u.size, id], this.uniforms[id] = loc;
            for (let j = 1; j < u.size; ++j) {
              let n = name + "[" + j + "]";
              let loc = this.ctx.getUniformLocation(p, n);
              let id = this.getNewId(this.uniforms);
              this.uniforms[id] = loc;
            }
          }
        }
      }

      getSource(shader, strings_ptr, strings_length) {
        const STRING_SIZE = 2*4;
        let source = "";
        for (let i = 0; i < strings_length; i++) {
          let ptr = this.mem.loadPtr(strings_ptr + i*STRING_SIZE);
          let len = this.mem.loadPtr(strings_ptr + i*STRING_SIZE + 4);
          let str = this.mem.loadString(ptr, len);
          source += str;
        }
        return source;
      }

      getWebGL1Interface() {
        return {
          ` + string(#load("../../src/platform/wasm/javascript/webgl.js")) + `
        };
      }
      {{#webgl_2}}

        getWebGL2Interface() {
          return {
            ` + string(#load("../../src/platform/wasm/javascript/webgl2.js")) + `
          };
        }
      {{/webgl_2}}
    };
  {{/webgl_1}}

  function odinSetupDefaultImports(wasmMemoryInterface) {
    let currentLine = {};
    currentLine[false] = "";
    currentLine[true] = "";
    let prevIsError = false;

    const writeToConsole = (line, isError) => {
      if (!line) {
        return;
      }

      const println = (text, forceIsError) => {
        let style = [
          "color: #eee",
          "background-color: #d20",
          "padding: 2px 4px",
          "border-radius: 2px",
        ].join(";");
        let doIsError = isError;
        if (forceIsError !== undefined) {
          doIsError = forceIsError;
        }

        if (doIsError) {
          console.log("%c"+text, style);
        } else {
          console.log(text);
        }

      };

      // Print to console
      if (line == "\n") {
        println(currentLine[isError], isError);
        currentLine[isError] = "";
      } else if (!line.includes("\n")) {
        currentLine[isError] = currentLine[isError].concat(line);
      } else {
        let lines = line.split("\n");
        let printLast = lines.length > 1 && line.endsWith("\n");
        println(currentLine[isError].concat(lines[0]), isError);
        currentLine[isError] = "";
        for (let i = 1; i < lines.length-1; i++) {
          println(lines[i], isError);
        }
        let last = lines[lines.length-1];
        if (printLast) {
          println(last, isError);
        } else {
          currentLine[isError] = last;
        }
      }

      if (prevIsError != isError) {
        if (prevIsError) {
          println(currentLine[prevIsError], prevIsError);
          currentLine[prevIsError] = "";
        }
      }
      prevIsError = isError;
    };

    const memory = new WebAssembly.Memory({
      initial: ` + mem.NUM_PAGES_STR[mem.WASM_PAGE_COUNT] + `,
      maximum: ` + mem.NUM_PAGES_STR[mem.WASM_PAGE_COUNT] + `
    });
    wasmMemoryInterface.setMemory(memory);

    let event_temp_data = {};
    {{#webgl_1}}
      window.webglContext = new WebGLInterface(wasmMemoryInterface);
    {{/webgl_1}}
    return {
      "env": { ` + string(#load("../../src/platform/wasm/javascript/env.js")) + ` },
      "audio": { ` + string(#load("../../src/platform/wasm/javascript/audio.js")) + ` },
      "odin_env": { ` + string(#load("../../src/platform/wasm/javascript/odin_env.js")) + ` },
      "odin_dom": { ` + string(#load("../../src/platform/wasm/javascript/odin_dom.js")) + ` },
      {{#webgl_1}}
        "webgl": window.webglContext.getWebGL1Interface(),
      {{/webgl_1}}
      {{#webgl_2}}
        "webgl2": window.webglContext.getWebGL2Interface(),
      {{/webgl_2}}
    };
  };

  let wasmMemoryInterface = new WasmMemoryInterface();

  let imports = odinSetupDefaultImports(wasmMemoryInterface);
  let exports = {};

  var wasm_data = Uint8Array.from(atob("{{base64_wasm}}"), c => c.charCodeAt(0));
  const module = await WebAssembly.compile(wasm_data)
  const instance = await WebAssembly.instantiate(module, imports);

  exports = instance.exports;
  wasmMemoryInterface.setExports(exports);

  {
    const odin_ctx = exports.default_context_ptr();
    exports._start(odin_ctx);
  }

  const odin_ctx = exports.default_context_ptr();
  let prevTimeStamp = undefined;
  const step = (currTimeStamp) => {
    if (prevTimeStamp == undefined) {
      prevTimeStamp = currTimeStamp;
    }

    const dt = (currTimeStamp - prevTimeStamp)*0.001;
    prevTimeStamp = currTimeStamp;
    exports.step(dt, odin_ctx);
    window.requestAnimationFrame(step);
  };

  window.requestAnimationFrame(step);
})();
`
