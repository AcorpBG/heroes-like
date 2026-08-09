@echo off
setlocal EnableExtensions DisableDelayedExpansion

if not defined HEROES_LIKE_INSTALL_DIR (
  if not defined LOCALAPPDATA (
    echo heroes-like uninstaller: LOCALAPPDATA is unavailable 1>&2
    exit /b 1
  )
  set "HEROES_LIKE_INSTALL_DIR=%LOCALAPPDATA%\Heroes Like"
)
if not defined HEROES_LIKE_START_MENU_DIR (
  if not defined APPDATA (
    echo heroes-like uninstaller: APPDATA is unavailable 1>&2
    exit /b 1
  )
  set "HEROES_LIKE_START_MENU_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Heroes Like"
)
if not defined TEMP (
  echo heroes-like uninstaller: TEMP is unavailable 1>&2
  exit /b 1
)

if /i not "%~1"=="--heroes-like-staged" goto :stage_uninstaller
if not "%~2"=="%HEROES_LIKE_UNINSTALL_TOKEN%" goto :stage_uninstaller
for %%I in ("%TEMP%\heroes-like-uninstall-%~2.cmd") do set "EXPECTED_UNINSTALL=%%~fI"
if /i "%~f0"=="%EXPECTED_UNINSTALL%" goto :uninstall_main

:stage_uninstaller
set "HEROES_LIKE_UNINSTALL_TOKEN=%RANDOM%-%RANDOM%-%RANDOM%"
set "TEMP_UNINSTALL=%TEMP%\heroes-like-uninstall-%HEROES_LIKE_UNINSTALL_TOKEN%.cmd"
if exist "%TEMP_UNINSTALL%" (
  echo heroes-like uninstaller: temporary uninstaller collision 1>&2
  exit /b 1
)
cd /d "%TEMP%"
if errorlevel 1 (
  echo heroes-like uninstaller: could not leave the program directory 1>&2
  exit /b 1
)
copy /y "%~f0" "%TEMP_UNINSTALL%" >nul
if errorlevel 1 (
  echo heroes-like uninstaller: could not stage the uninstaller outside the program directory 1>&2
  exit /b 1
)
rem Transfer control instead of CALLing. Keeping the installed batch on the
rem command stack would hold its program directory open during final removal.
"%TEMP_UNINSTALL%" --heroes-like-staged "%HEROES_LIKE_UNINSTALL_TOKEN%"

:uninstall_main
for %%I in ("%HEROES_LIKE_INSTALL_DIR%") do set "INSTALL_ROOT=%%~fI"
for %%I in ("%HEROES_LIKE_START_MENU_DIR%") do set "START_MENU_ROOT=%%~fI"
for %%I in ("%INSTALL_ROOT%") do (
  set "INSTALL_DRIVE=%%~dI"
  set "INSTALL_LEAF=%%~nxI"
)
for %%I in ("%START_MENU_ROOT%") do set "START_MENU_DRIVE=%%~dI"
if not defined INSTALL_DRIVE goto :unsafe_install_root
if not defined INSTALL_LEAF goto :unsafe_install_root
if /i "%INSTALL_ROOT%"=="%INSTALL_DRIVE%\" goto :unsafe_install_root
if not defined START_MENU_DRIVE goto :unsafe_start_menu
if /i "%START_MENU_ROOT%"=="%START_MENU_DRIVE%\" goto :unsafe_start_menu

call :reject_bang "%INSTALL_ROOT%"
if errorlevel 1 goto :unsupported_path
call :reject_bang "%START_MENU_ROOT%"
if errorlevel 1 goto :unsupported_path
call :reject_bang "%TEMP%"
if errorlevel 1 goto :unsupported_path
for %%P in ("%SystemRoot%" "%USERPROFILE%" "%LOCALAPPDATA%" "%APPDATA%" "%TEMP%") do (
  call :mark_forbidden_root "%%~P"
)
if defined UNSAFE_INSTALL_MATCH goto :unsafe_install_root
if defined UNSAFE_START_MENU_MATCH goto :unsafe_start_menu
call :paths_overlap "%INSTALL_ROOT%" "%START_MENU_ROOT%"
if errorlevel 1 (
  echo heroes-like uninstaller: install and Start Menu directories must not overlap 1>&2
  exit /b 1
)
if not exist "%INSTALL_ROOT%\NUL" (
  echo heroes-like uninstaller: owned install directory is missing 1>&2
  exit /b 1
)

set "HELPER=%INSTALL_ROOT%\heroes-like-installer-helper.exe"
if not exist "%HELPER%" (
  echo heroes-like uninstaller: manifest-owned installer helper is missing 1>&2
  exit /b 1
)
set "TOKEN=%RANDOM%-%RANDOM%-%RANDOM%"
set "TEMP_HELPER=%TEMP%\heroes-like-installer-helper-%TOKEN%.exe"
set "TEMP_CLEANUP=%TEMP%\heroes-like-uninstall-cleanup-%TOKEN%.cmd"
set "EXPECTED_LAUNCHER=%START_MENU_ROOT%\.Heroes Like.cmd.expected-%TOKEN%"
set "LAUNCHER=%START_MENU_ROOT%\Heroes Like.cmd"

call :validate_marker "%INSTALL_ROOT%\.heroes-like-install"
if errorlevel 1 goto :uninstall_fail
call :validate_required_payload "%INSTALL_ROOT%"
if errorlevel 1 goto :uninstall_fail
"%HELPER%" verify "%INSTALL_ROOT%\release-manifest.json" "%INSTALL_ROOT%" windows-x86_64 release-manifest.json .heroes-like-install
if errorlevel 1 (
  echo heroes-like uninstaller: refusing uninstall because the program root is not an exact manifest-owned set 1>&2
  goto :uninstall_fail
)
if exist "%TEMP_HELPER%" (
  echo heroes-like uninstaller: temporary helper collision 1>&2
  goto :uninstall_fail
)
copy /y "%HELPER%" "%TEMP_HELPER%" >nul
if errorlevel 1 goto :uninstall_fail
"%SystemRoot%\System32\fc.exe" /b "%HELPER%" "%TEMP_HELPER%" >nul
if errorlevel 1 (
  echo heroes-like uninstaller: temporary helper copy failed identity verification 1>&2
  goto :uninstall_fail
)

if exist "%START_MENU_ROOT%" if not exist "%START_MENU_ROOT%\NUL" (
  echo heroes-like uninstaller: Start Menu path is not a directory 1>&2
  goto :uninstall_fail
)
if exist "%LAUNCHER%" (
  if exist "%EXPECTED_LAUNCHER%" (
    echo heroes-like uninstaller: launcher validation-file collision 1>&2
    goto :uninstall_fail
  )
  >"%EXPECTED_LAUNCHER%" echo @echo off
  >>"%EXPECTED_LAUNCHER%" echo start "" "%INSTALL_ROOT%\heroes-like.exe" %%*
  "%SystemRoot%\System32\fc.exe" /b "%LAUNCHER%" "%EXPECTED_LAUNCHER%" >nul
  if errorlevel 1 (
    echo heroes-like uninstaller: refusing to remove a modified Start Menu launcher 1>&2
    goto :uninstall_fail
  )
)

if exist "%LAUNCHER%" del /f /q "%LAUNCHER%" >nul 2>&1
if exist "%LAUNCHER%" (
  echo heroes-like uninstaller: could not remove the owned Start Menu launcher 1>&2
  goto :uninstall_fail
)
"%TEMP_HELPER%" remove "%INSTALL_ROOT%\release-manifest.json" "%INSTALL_ROOT%" windows-x86_64 release-manifest.json .heroes-like-install
if errorlevel 1 (
  echo heroes-like uninstaller: verified manifest-owned file removal failed 1>&2
  goto :uninstall_fail
)
del /f /q "%INSTALL_ROOT%\release-manifest.json" "%INSTALL_ROOT%\.heroes-like-install" >nul 2>&1
if exist "%INSTALL_ROOT%\release-manifest.json" goto :uninstall_fail
if exist "%INSTALL_ROOT%\.heroes-like-install" goto :uninstall_fail
cd /d "%TEMP%"
del /f /q "%EXPECTED_LAUNCHER%" >nul 2>&1
rmdir "%START_MENU_ROOT%" >nul 2>&1
del /f /q "%TEMP_HELPER%" >nul 2>&1
if exist "%TEMP_CLEANUP%" (
  echo heroes-like uninstaller: temporary cleanup collision 1>&2
  goto :uninstall_fail
)
>"%TEMP_CLEANUP%" echo @echo off
>>"%TEMP_CLEANUP%" echo ping 127.0.0.1 -n 2 ^>nul
>>"%TEMP_CLEANUP%" echo rmdir "%INSTALL_ROOT%" ^>nul 2^>^&1
>>"%TEMP_CLEANUP%" echo del /f /q "%EXPECTED_UNINSTALL%" ^>nul 2^>^&1
>>"%TEMP_CLEANUP%" echo del /f /q "%TEMP_CLEANUP%" ^>nul 2^>^&1
start "" /b "%ComSpec%" /d /c ""%TEMP_CLEANUP%""
if errorlevel 1 (
  echo heroes-like uninstaller: could not schedule final owned-root cleanup 1>&2
  goto :uninstall_fail
)
echo heroes-like program files removed
echo Saved games, settings, generated maps, and runtime logs were preserved.
exit /b 0

:uninstall_fail
del /f /q "%TEMP_HELPER%" "%TEMP_CLEANUP%" "%EXPECTED_LAUNCHER%" >nul 2>&1
exit /b 1

:validate_required_payload
setlocal DisableDelayedExpansion
for %%F in (heroes-like.exe heroes-like.pck aurelion_map_persistence.windows.template_release.x86_64.dll README.txt build-info.json install.cmd uninstall.cmd heroes-like-installer-helper.exe) do (
  if not exist "%~1\%%F" (
    echo heroes-like uninstaller: required manifest-owned payload "%%F" is missing 1>&2
    endlocal & exit /b 1
  )
)
endlocal & exit /b 0

:validate_marker
setlocal DisableDelayedExpansion
if not exist "%~1" (
  echo heroes-like uninstaller: install ownership marker is missing 1>&2
  endlocal & exit /b 1
)
set "OWNER="
set /p "OWNER="<"%~1"
if not "%OWNER%"=="heroes-like-user-local-install-v1" (
  echo heroes-like uninstaller: install ownership marker is invalid 1>&2
  endlocal & exit /b 1
)
endlocal & exit /b 0

:mark_forbidden_root
if "%~1"=="" exit /b 0
for %%R in ("%~1") do (
  if /i "%INSTALL_ROOT%"=="%%~fR" set "UNSAFE_INSTALL_MATCH=1"
  if /i "%START_MENU_ROOT%"=="%%~fR" set "UNSAFE_START_MENU_MATCH=1"
)
exit /b 0

:reject_bang
setlocal DisableDelayedExpansion
set "PATH_VALUE=%~1"
set "PATH_WITHOUT_BANG=%PATH_VALUE:!=%"
if not "%PATH_VALUE%"=="%PATH_WITHOUT_BANG%" goto :reject_bang_yes
endlocal & exit /b 0
:reject_bang_yes
endlocal & exit /b 1

:paths_overlap
setlocal EnableDelayedExpansion
set "LEFT=%~1\"
set "RIGHT=%~2\"
call :string_length "!LEFT!" LEFT_LENGTH
call :string_length "!RIGHT!" RIGHT_LENGTH
for %%N in (!RIGHT_LENGTH!) do set "LEFT_PREFIX=!LEFT:~0,%%N!"
for %%N in (!LEFT_LENGTH!) do set "RIGHT_PREFIX=!RIGHT:~0,%%N!"
if /i "!LEFT_PREFIX!"=="!RIGHT!" goto :paths_overlap_yes
if /i "!RIGHT_PREFIX!"=="!LEFT!" goto :paths_overlap_yes
endlocal & exit /b 0
:paths_overlap_yes
endlocal & exit /b 1

:string_length
setlocal EnableDelayedExpansion
set "STRING_VALUE=%~1"
set "STRING_LENGTH=0"
:string_length_loop
if not defined STRING_VALUE goto :string_length_done
set "STRING_VALUE=!STRING_VALUE:~1!"
set /a STRING_LENGTH+=1
goto :string_length_loop
:string_length_done
endlocal & set "%~2=%STRING_LENGTH%"
exit /b 0

:unsupported_path
echo heroes-like uninstaller: paths containing ! are not supported 1>&2
exit /b 1

:unsafe_install_root
echo heroes-like uninstaller: refusing unsafe install directory "%INSTALL_ROOT%" 1>&2
exit /b 1

:unsafe_start_menu
echo heroes-like uninstaller: refusing unsafe Start Menu directory "%START_MENU_ROOT%" 1>&2
exit /b 1
