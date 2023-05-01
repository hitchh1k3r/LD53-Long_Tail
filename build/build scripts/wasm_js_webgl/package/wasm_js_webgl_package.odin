package pack

import "core:encoding/base64"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

import "project:platform/wasm/mem"
import "project:../meta/popen"

TITLE :: "Jellbreak 2023"
WEB_GL :: 2
IMPORTS := map[string]string{
    "env" = string(#load("../../../src/platform/wasm/javascript/env.js")),
    "audio" = string(#load("../../../src/platform/wasm/javascript/audio.js")),
    "odin_env" = string(#load("../../../src/platform/wasm/javascript/odin_env.js")),
    "odin_dom" = string(#load("../../../src/platform/wasm/javascript/odin_dom.js")),
  }

main :: proc()
{
  assert(len(os.args) == 2)
  assert(os.args[1] == "debug" || os.args[1] == "release")

  switch os.args[1] {
    case "debug":
      {
        wasmFile, ok := os.read_entire_file("build/wasm_js_webgl/_temp/wasm.wasm")
        assert(ok)
        write_js_file("build/wasm_js_webgl/_temp/full-size.js", wasmFile)
      }

      {
        jsFile, ok := os.read_entire_file("build/wasm_js_webgl/_temp/full-size.js")
        assert(ok)
        write_html_file("build/wasm_js_webgl/index.html", transmute(string) jsFile)
      }
    case "release":
      {
        wasmFile, ok := os.read_entire_file("build/wasm_js_webgl/_temp/optimized.wasm")
        assert(ok)
        write_js_file("build/wasm_js_webgl/_temp/full-size.js", wasmFile)
      }

      stdout, exit_code := popen.exec("java -jar \"build scripts/wasm_js_webgl/libs/closure-compiler.jar\" --js build/wasm_js_webgl/_temp/full-size.js --js_output_file build/wasm_js_webgl/_temp/min.js") //  --compilation_level ADVANCED_OPTIMIZATIONS
      fmt.printf("> closure-compiler.jar\n%v\n", stdout)

      if exit_code != 0 {
        fmt.eprintln("Failed to compress javascript...")
        os.exit(1)
      }

      {
        jsFile, ok := os.read_entire_file("build/wasm_js_webgl/_temp/full-size.js")
        assert(ok)
        write_html_file("build/wasm_js_webgl/index.html", transmute(string) jsFile)
      }
    case:
      fmt.eprintf("Usage: %v [debug/release]\n", os.args[0])
  }

  os.exit(99)
}

write_js_file :: proc(fileName : string, wasmData : []byte)
{
  b := strings.builder_make()
  defer strings.builder_destroy(&b)
  defer os.write_entire_file(fileName, b.buf[:])
  strings.write_string(&b, `"use strict";
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
      };`)
  when WEB_GL > 0 {
    strings.write_string(&b, `
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
        }`)

    when WEB_GL >= 1 {
      strings.write_string(&b, `
        getWebGL1Interface() {
          return {
            ` + string(#load("../../../src/platform/wasm/javascript/webgl.js")) + `
          };
        }`)
    }

    when WEB_GL >= 2 {
      strings.write_string(&b, `
        getWebGL2Interface() {
          return {
            ` + string(#load("../../../src/platform/wasm/javascript/webgl2.js")) + `
          };
        }`)
    }
    strings.write_string(&b, `
      };`)
  }
  strings.write_string(&b, `
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
            println(currentLine[isError]);
            currentLine[isError] = "";
          } else if (!line.includes("\n")) {
            currentLine[isError] = currentLine[isError].concat(line);
          } else {
            let lines = line.split("\n");
            let printLast = lines.length > 1 && line.endsWith("\n");
            println(currentLine[isError].concat(lines[0]));
            currentLine[isError] = "";
            for (let i = 1; i < lines.length-1; i++) {
              println(lines[i]);
            }
            let last = lines[lines.length-1];
            if (printLast) {
              println(last);
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

        let event_temp_data = {};`)
  when WEB_GL > 0 {
    strings.write_string(&b, `
        window.webglContext = new WebGLInterface(wasmMemoryInterface);`)
  }
    strings.write_string(&b, `
        return {`)
  for name, js in IMPORTS {
    strings.write_string(&b, `
          "`)
    strings.write_string(&b, name)
    strings.write_string(&b, `": {`)
    strings.write_string(&b, js)
    strings.write_string(&b, `},`)
  }
  when WEB_GL >= 1 {
    strings.write_string(&b, `
          "webgl": window.webglContext.getWebGL1Interface(),`)
  }
  when WEB_GL >= 2 {
    strings.write_string(&b, `
          "webgl2": window.webglContext.getWebGL2Interface(),`)
  }
  strings.write_string(&b, `
        };
      };

      let wasmMemoryInterface = new WasmMemoryInterface();

      let imports = odinSetupDefaultImports(wasmMemoryInterface);
      let exports = {};

      var wasm_data = Uint8Array.from(atob("`)
  base64 := base64.encode(wasmData)
  defer delete(base64)
  strings.write_string(&b, base64)
  strings.write_string(&b, `"), c => c.charCodeAt(0));
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
    })();`)
}

write_html_file :: proc(fileName : string, jsString : string)
{
  b := strings.builder_make()
  defer strings.builder_destroy(&b)
  defer os.write_entire_file(fileName, b.buf[:])

  strings.write_string(&b,
    `<!doctype html>` +
    `<html>` +
      `<head>` +
        `<title>` + TITLE + `</title>` +
        `<style>` +
          `*{margin:0;padding:0;}` +
          `html,body{width:100%;height:100%;overflow:hidden;}` +
        `</style>` +
      `</head>` +
      `<body>` +
        `Please enable JavaScript (or check console for errors)` +
        `<script>`)

  strings.write_string(&b, strings.trim_space(jsString))

  strings.write_string(&b,
        `</script>` +
      `</body>` +
    `</html>`)
}
