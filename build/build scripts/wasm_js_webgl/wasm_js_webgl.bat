@echo off

IF "%1"=="debug" (

  :: Debug Mode Build Options:
  set build_options=-o:none -debug

) ELSE IF "%1"=="release" (

  :: Release Mode Build Options:
  set build_options=-o:size -vet -strict-style -disable-assert -no-bounds-check

) ELSE (
  echo Invalid input argument. Please use "debug" or "release".
  exit /b 1
)

odin build src/wasm_js_webgl.odin -file -out:"build/wasm_js_webgl/_temp/wasm.wasm" ^
     -target:js_wasm32 -warnings-as-errors -ignore-unknown-attributes -collection:project=./src/ %build_options% ^
     -ignore-vs-search -no-crt -extra-linker-flags:"--import-memory --lto-O3 --gc-sections --strip-all --export=__heap_base --export=__data_end"

if %ERRORLEVEL% neq 0 (
  exit /b 1
)

call "build scripts/wasm_js_webgl/libs/wasm-opt-win64.exe" -Oz --zero-filled-memory --strip-producers "build/wasm_js_webgl/_temp/wasm.wasm" -o "build/wasm_js_webgl/_temp/optimized.wasm"

if %ERRORLEVEL% neq 0 (
  exit /b 1
)

odin run "build scripts/wasm_js_webgl/package/" -out:"build scripts/wasm_js_webgl/package.exe" -collection:project=./src/ -- %1

if %ERRORLEVEL% neq 99 (
  exit /b 1
)
