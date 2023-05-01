@echo off

IF "%1"=="debug" (

  :: Debug Mode Build Options:
  set build_options=-o:none -debug

) ELSE IF "%1"=="release" (

  :: Release Mode Build Options:
  set build_options=-o:speed -vet -strict-style

) ELSE (
  echo Invalid input argument. Please use "debug" or "release".
  exit /b 1
)

copy build\resources build\windows64_win32_opengl\resources
odin run src/windows_64_win32_opengl.odin -file -out:"build/windows64_win32_opengl/Gel Break 2022.exe" -warnings-as-errors -ignore-unknown-attributes -collection:project=./src/ %build_options%
