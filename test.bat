@echo off

pushd "%~dp0"

call odin test tests ^
    -out:build/tests.exe ^
    -vet ^
    -all-packages ^
    -debug

if %ERRORLEVEL% NEQ 0 exit /b 1

popd