@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.." >nul || (
	echo Failed to locate repository root from %SCRIPT_DIR%..
	exit /b 1
)

set "BUILD_DEBUG=1"
set "BUILD_RELEASE=1"
set "SKIP_TEST=0"
set "REQUIRE_TEST=0"
set "USE_MINGW=0"
set "ALLOW_OTHER_GODOT_VERSION=0"
set "EXPECTED_GODOT_VERSION=4.6.2"
set "PARALLEL=2"
set "GODOT_EXE=godot"

:parse_args
if "%~1"=="" goto after_args
if /I "%~1"=="--help" goto usage
if /I "%~1"=="-h" goto usage
if /I "%~1"=="--debug-only" (
	set "BUILD_DEBUG=1"
	set "BUILD_RELEASE=0"
	shift
	goto parse_args
)
if /I "%~1"=="--release-only" (
	set "BUILD_DEBUG=0"
	set "BUILD_RELEASE=1"
	shift
	goto parse_args
)
if /I "%~1"=="--skip-test" (
	set "SKIP_TEST=1"
	shift
	goto parse_args
)
if /I "%~1"=="--require-test" (
	set "REQUIRE_TEST=1"
	shift
	goto parse_args
)
if /I "%~1"=="--mingw" (
	set "USE_MINGW=1"
	shift
	goto parse_args
)
if /I "%~1"=="--allow-other-godot-version" (
	set "ALLOW_OTHER_GODOT_VERSION=1"
	shift
	goto parse_args
)
if /I "%~1"=="--parallel" (
	shift
	if "%~1"=="" (
		echo Missing value for --parallel.
		goto usage_error
	)
	set "PARALLEL=%~1"
	shift
	goto parse_args
)
if /I "%~1"=="--godot" (
	shift
	if "%~1"=="" (
		echo Missing value for --godot.
		goto usage_error
	)
	set "GODOT_EXE=%~1"
	shift
	goto parse_args
)

echo Unknown argument: %~1
goto usage_error

:after_args
echo Repository root: %CD%

where git >nul 2>nul || (
	echo git was not found on PATH.
	popd >nul
	exit /b 1
)

where cmake >nul 2>nul || (
	echo cmake was not found on PATH.
	popd >nul
	exit /b 1
)

call :run git submodule update --init --recursive third_party/godot-cpp
if errorlevel 1 goto fail

if "%USE_MINGW%"=="1" (
	call :build_mingw
) else (
	call :build_msvc
)
if errorlevel 1 goto fail

call :verify_outputs
if errorlevel 1 goto fail

if "%SKIP_TEST%"=="1" (
	echo Skipping Godot smokes because --skip-test was provided.
) else (
	call :run_smoke
	if errorlevel 1 goto fail
)

echo.
echo Windows map persistence GDExtension helper completed successfully.
popd >nul
exit /b 0

:build_msvc
set "MSVC_BUILD_DIR=.artifacts\map_persistence_native_build_windows_msvc"
call :run cmake -S src\gdextension -B "%MSVC_BUILD_DIR%" -G "Visual Studio 17 2022" -A x64
if errorlevel 1 exit /b 1
if "%BUILD_DEBUG%"=="1" (
	call :run cmake --build "%MSVC_BUILD_DIR%" --config Debug --parallel %PARALLEL%
	if errorlevel 1 exit /b 1
)
if "%BUILD_RELEASE%"=="1" (
	call :run cmake --build "%MSVC_BUILD_DIR%" --config Release --parallel %PARALLEL%
	if errorlevel 1 exit /b 1
)
exit /b 0

:build_mingw
if "%BUILD_DEBUG%"=="1" (
	set "MINGW_DEBUG_DIR=.artifacts\map_persistence_native_build_windows_mingw_debug"
	call :run cmake -S src\gdextension -B "!MINGW_DEBUG_DIR!" -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Debug
	if errorlevel 1 exit /b 1
	call :run cmake --build "!MINGW_DEBUG_DIR!" --parallel %PARALLEL%
	if errorlevel 1 exit /b 1
)
if "%BUILD_RELEASE%"=="1" (
	set "MINGW_RELEASE_DIR=.artifacts\map_persistence_native_build_windows_mingw_release"
	call :run cmake -S src\gdextension -B "!MINGW_RELEASE_DIR!" -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release
	if errorlevel 1 exit /b 1
	call :run cmake --build "!MINGW_RELEASE_DIR!" --parallel %PARALLEL%
	if errorlevel 1 exit /b 1
)
exit /b 0

:verify_outputs
if "%BUILD_DEBUG%"=="1" (
	if not exist "bin\aurelion_map_persistence.windows.template_debug.x86_64.dll" (
		echo Missing expected Debug DLL: bin\aurelion_map_persistence.windows.template_debug.x86_64.dll
		exit /b 1
	)
	echo Found Debug DLL: bin\aurelion_map_persistence.windows.template_debug.x86_64.dll
)
if "%BUILD_RELEASE%"=="1" (
	if not exist "bin\aurelion_map_persistence.windows.template_release.x86_64.dll" (
		echo Missing expected Release DLL: bin\aurelion_map_persistence.windows.template_release.x86_64.dll
		exit /b 1
	)
	echo Found Release DLL: bin\aurelion_map_persistence.windows.template_release.x86_64.dll
)
exit /b 0

:run_smoke
echo Headless/editor smokes load windows.editor.x86_64 from the GDExtension manifest, which points at the Debug DLL.
if not exist "bin\aurelion_map_persistence.windows.template_debug.x86_64.dll" (
	echo Missing Debug DLL required by editor/headless smokes: bin\aurelion_map_persistence.windows.template_debug.x86_64.dll
	echo Build Debug first, use --debug-only, or pass --skip-test for a release-only build.
	exit /b 1
)

set "GODOT_FOUND=0"
if exist "%GODOT_EXE%" set "GODOT_FOUND=1"
if "%GODOT_FOUND%"=="0" (
	where "%GODOT_EXE%" >nul 2>nul && set "GODOT_FOUND=1"
)

if "%GODOT_FOUND%"=="0" (
	echo Godot was not found on PATH.
	echo Build succeeded. To run the focused smokes manually, add Godot %EXPECTED_GODOT_VERSION% to PATH or pass --godot PATH_TO_4_6_2_EXE, then run:
	echo Godot_v4.6.2-stable_win64.exe --headless --path . tests/map_package_api_skeleton_report.tscn
	echo Godot_v4.6.2-stable_win64.exe --headless --path . tests/native_random_map_foundation_report.tscn
	if "%REQUIRE_TEST%"=="1" (
		echo Failing because --require-test was provided.
		exit /b 1
	)
	exit /b 0
)

call :check_godot_version
if errorlevel 1 exit /b 1

set "GODOT_SILENCE_ROOT_WARNING=1"
call :run "%GODOT_EXE%" --headless --path . tests/map_package_api_skeleton_report.tscn
if errorlevel 1 exit /b 1
call :run "%GODOT_EXE%" --headless --path . tests/native_random_map_foundation_report.tscn
exit /b %ERRORLEVEL%

:check_godot_version
set "DETECTED_GODOT_VERSION="
for /F "usebackq delims=" %%V in (`"%GODOT_EXE%" --version 2^>^&1`) do (
	if not defined DETECTED_GODOT_VERSION set "DETECTED_GODOT_VERSION=%%V"
)
if not defined DETECTED_GODOT_VERSION (
	echo Failed to detect Godot version from: %GODOT_EXE% --version
	echo Expected Godot %EXPECTED_GODOT_VERSION%; pass --godot PATH_TO_4_6_2_EXE or --allow-other-godot-version.
	exit /b 1
)
echo Detected Godot version: !DETECTED_GODOT_VERSION!
if "%ALLOW_OTHER_GODOT_VERSION%"=="1" (
	echo Allowing non-%EXPECTED_GODOT_VERSION% Godot version because --allow-other-godot-version was provided.
	exit /b 0
)
echo(!DETECTED_GODOT_VERSION! | find "%EXPECTED_GODOT_VERSION%" >nul
if errorlevel 1 (
	echo Expected Godot %EXPECTED_GODOT_VERSION%; pass --godot PATH_TO_4_6_2_EXE or --allow-other-godot-version.
	exit /b 1
)
exit /b 0

:run
echo.
echo ^> %*
%*
if errorlevel 1 (
	set "RUN_EXIT=%ERRORLEVEL%"
	echo Command failed with exit code !RUN_EXIT!.
	exit /b !RUN_EXIT!
)
exit /b 0

:usage_error
call :print_usage
popd >nul
exit /b 2

:usage
call :print_usage
popd >nul
exit /b 0

:print_usage
echo Usage: scripts\build_map_persistence_windows.bat [options]
echo.
echo Builds the Windows x86_64 map persistence GDExtension DLLs from the repository root.
echo Headless/editor smokes use the manifest's windows.editor.x86_64 entry, which points at the Debug DLL.
echo.
echo Options:
echo   --debug-only       Build and verify only the Debug DLL; sufficient for headless/editor smokes.
echo   --release-only     Build and verify only the Release DLL; use --skip-test unless a Debug DLL already exists.
echo   --skip-test        Do not run the focused Godot smokes.
echo   --require-test     Fail when Godot is not available or either smoke fails.
echo   --mingw            Use MinGW Makefiles instead of Visual Studio 2022.
echo   --parallel N       Build with N parallel jobs. Default: 2.
echo   --godot PATH       Use a specific Godot executable for the smokes.
echo   --allow-other-godot-version
echo                      Allow smokes with a Godot version other than 4.6.2.
echo   --help             Show this help.
echo.
echo Expected outputs:
echo   bin\aurelion_map_persistence.windows.template_debug.x86_64.dll
echo   bin\aurelion_map_persistence.windows.template_release.x86_64.dll
exit /b 0

:fail
echo.
echo Windows map persistence GDExtension helper failed.
popd >nul
exit /b 1
