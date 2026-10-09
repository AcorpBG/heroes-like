@echo off
rem Builds h3trace.exe (32-bit) next to this script with MSVC Build Tools 2022.
rem Usage notes and evidence: .artifacts/rmg_recovery/support/windows_h3maped_parity_basis_20261009/README.md
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars32.bat" >nul
cd /d "%~dp0"
cl /nologo /O2 /MT /W3 /D_CRT_SECURE_NO_WARNINGS h3trace.c user32.lib /Fe:h3trace.exe
echo exit=%ERRORLEVEL%
