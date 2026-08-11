@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "SOURCE_DIR=%~dp0"
if not defined HEROES_LIKE_INSTALL_DIR (
  if not defined LOCALAPPDATA (
    echo heroes-like installer: LOCALAPPDATA is unavailable 1>&2
    exit /b 1
  )
  set "HEROES_LIKE_INSTALL_DIR=%LOCALAPPDATA%\Heroes Like"
)
if not defined HEROES_LIKE_START_MENU_DIR (
  if not defined APPDATA (
    echo heroes-like installer: APPDATA is unavailable 1>&2
    exit /b 1
  )
  set "HEROES_LIKE_START_MENU_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Heroes Like"
)
if not defined TEMP (
  echo heroes-like installer: TEMP is unavailable 1>&2
  exit /b 1
)
if defined HEROES_LIKE_INSTALL_FAIL_PHASE if /i not "%HEROES_LIKE_INSTALL_FAIL_PHASE%"=="precommit" if /i not "%HEROES_LIKE_INSTALL_FAIL_PHASE%"=="after_backup" (
  echo heroes-like installer: unsupported HEROES_LIKE_INSTALL_FAIL_PHASE "%HEROES_LIKE_INSTALL_FAIL_PHASE%" 1>&2
  exit /b 1
)

for %%I in ("%SOURCE_DIR%.") do set "SOURCE_ROOT=%%~fI"
for %%I in ("%HEROES_LIKE_INSTALL_DIR%") do set "INSTALL_ROOT=%%~fI"
for %%I in ("%HEROES_LIKE_START_MENU_DIR%") do set "START_MENU_ROOT=%%~fI"
for %%I in ("%INSTALL_ROOT%") do (
  set "INSTALL_DRIVE=%%~dI"
  set "INSTALL_PARENT=%%~dpI"
  set "INSTALL_LEAF=%%~nxI"
)
for %%I in ("%START_MENU_ROOT%") do set "START_MENU_DRIVE=%%~dI"
if not defined INSTALL_DRIVE goto :unsafe_install_root
if not defined INSTALL_LEAF goto :unsafe_install_root
if /i "%INSTALL_ROOT%"=="%INSTALL_DRIVE%\" goto :unsafe_install_root
if not defined START_MENU_DRIVE goto :unsafe_start_menu
if /i "%START_MENU_ROOT%"=="%START_MENU_DRIVE%\" goto :unsafe_start_menu

call :reject_bang "%SOURCE_ROOT%"
if errorlevel 1 goto :unsupported_path
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
if errorlevel 1 goto :overlapping_paths
call :paths_overlap "%INSTALL_ROOT%" "%SOURCE_ROOT%"
if errorlevel 1 goto :overlapping_paths

set "HELPER=%SOURCE_ROOT%\heroes-like-installer-helper.exe"
set "SOURCE_MANIFEST=%SOURCE_ROOT%\release-manifest.json"
if not exist "%HELPER%" (
  echo heroes-like installer: missing payload heroes-like-installer-helper.exe 1>&2
  exit /b 1
)
if not exist "%SOURCE_MANIFEST%" (
  echo heroes-like installer: missing payload release-manifest.json 1>&2
  exit /b 1
)

set "TOKEN=%RANDOM%-%RANDOM%-%RANDOM%"
set "STAGE_ROOT=%INSTALL_PARENT%.%INSTALL_LEAF%.stage-%TOKEN%"
set "BACKUP_ROOT=%INSTALL_PARENT%.%INSTALL_LEAF%.backup-%TOKEN%"
set "LAUNCHER=%START_MENU_ROOT%\Aurelion Reach.cmd"
set "LEGACY_LAUNCHER=%START_MENU_ROOT%\Heroes Like.cmd"
set "LAUNCHER_NEW=%START_MENU_ROOT%\.Aurelion Reach.cmd.new-%TOKEN%"
set "LAUNCHER_BACKUP=%START_MENU_ROOT%\.Aurelion Reach.cmd.backup-%TOKEN%"
set "INSTALL_EXISTED=0"
set "HAS_PRIOR_INSTALL=0"
set "BACKUP_MOVED=0"
set "NEW_COMMITTED=0"
set "LAUNCHER_PUBLISHED=0"
set "START_MENU_CREATED=0"

call :validate_required_payload "%SOURCE_ROOT%"
if errorlevel 1 goto :install_fail
"%HELPER%" verify "%SOURCE_MANIFEST%" "%SOURCE_ROOT%" windows-x86_64 release-manifest.json
if errorlevel 1 (
  echo heroes-like installer: release payload failed exact manifest verification 1>&2
  goto :install_fail
)

if exist "%INSTALL_ROOT%" (
  if not exist "%INSTALL_ROOT%\NUL" (
    echo heroes-like installer: install directory path is not a directory 1>&2
    goto :install_fail
  )
  if exist "%INSTALL_ROOT%\.heroes-like-install" (
    set "INSTALL_EXISTED=1"
    set "HAS_PRIOR_INSTALL=1"
    call :validate_marker "%INSTALL_ROOT%\.heroes-like-install"
    if errorlevel 1 goto :install_fail
    call :validate_required_payload "%INSTALL_ROOT%"
    if errorlevel 1 goto :install_fail
    "%HELPER%" verify "%INSTALL_ROOT%\release-manifest.json" "%INSTALL_ROOT%" windows-x86_64 release-manifest.json .heroes-like-install
    if errorlevel 1 (
      echo heroes-like installer: existing install is not an exact manifest-owned program set 1>&2
      goto :install_fail
    )
  ) else (
    rmdir "%INSTALL_ROOT%" >nul 2>&1
    if exist "%INSTALL_ROOT%" (
      echo heroes-like installer: refusing nonempty unowned install directory 1>&2
      goto :install_fail
    )
  )
)

if exist "%LAUNCHER%" (
  if not "%HAS_PRIOR_INSTALL%"=="1" (
    echo heroes-like installer: refusing to replace an unowned Start Menu launcher 1>&2
    goto :install_fail
  )
  >"%LAUNCHER_NEW%" echo @echo off
  >>"%LAUNCHER_NEW%" echo start "" "%INSTALL_ROOT%\heroes-like.exe" %%*
  "%SystemRoot%\System32\fc.exe" /b "%LAUNCHER%" "%LAUNCHER_NEW%" >nul
  if errorlevel 1 (
    echo heroes-like installer: refusing to replace a modified Start Menu launcher 1>&2
    goto :install_fail
  )
)
if exist "%LEGACY_LAUNCHER%" (
  if not "%HAS_PRIOR_INSTALL%"=="1" (
    echo heroes-like installer: refusing to replace an unowned legacy Start Menu launcher 1>&2
    goto :install_fail
  )
  >"%LAUNCHER_NEW%" echo @echo off
  >>"%LAUNCHER_NEW%" echo start "" "%INSTALL_ROOT%\heroes-like.exe" %%*
  "%SystemRoot%\System32\fc.exe" /b "%LEGACY_LAUNCHER%" "%LAUNCHER_NEW%" >nul
  if errorlevel 1 (
    echo heroes-like installer: refusing to replace a modified legacy Start Menu launcher 1>&2
    goto :install_fail
  )
)
if exist "%LAUNCHER_BACKUP%" (
  echo heroes-like installer: launcher backup collision 1>&2
  goto :install_fail
)

if exist "%STAGE_ROOT%" (
  echo heroes-like installer: staging directory collision 1>&2
  goto :install_fail
)
if exist "%BACKUP_ROOT%" (
  echo heroes-like installer: backup directory collision 1>&2
  goto :install_fail
)
if not exist "%INSTALL_PARENT%\NUL" mkdir "%INSTALL_PARENT%" >nul 2>&1
if not exist "%INSTALL_PARENT%\NUL" (
  echo heroes-like installer: install parent directory is unavailable 1>&2
  goto :install_fail
)
"%HELPER%" copy "%SOURCE_MANIFEST%" "%SOURCE_ROOT%" "%STAGE_ROOT%" windows-x86_64
if errorlevel 1 (
  echo heroes-like installer: verified payload staging failed 1>&2
  goto :install_fail
)
>"%STAGE_ROOT%\.heroes-like-install" echo heroes-like-user-local-install-v1
if errorlevel 1 goto :install_fail
"%HELPER%" verify "%STAGE_ROOT%\release-manifest.json" "%STAGE_ROOT%" windows-x86_64 release-manifest.json .heroes-like-install
if errorlevel 1 (
  echo heroes-like installer: staged payload failed exact manifest verification 1>&2
  goto :install_fail
)

if /i "%HEROES_LIKE_INSTALL_FAIL_PHASE%"=="precommit" (
  echo heroes-like installer: injected precommit failure 1>&2
  goto :install_fail
)
if not exist "%START_MENU_ROOT%\NUL" (
  mkdir "%START_MENU_ROOT%" >nul 2>&1
  if not exist "%START_MENU_ROOT%\NUL" goto :install_fail
  set "START_MENU_CREATED=1"
)
if not exist "%START_MENU_ROOT%\NUL" (
  echo heroes-like installer: Start Menu path is not a directory 1>&2
  goto :install_fail
)
if not exist "%LAUNCHER_NEW%" (
  >"%LAUNCHER_NEW%" echo @echo off
  >>"%LAUNCHER_NEW%" echo start "" "%INSTALL_ROOT%\heroes-like.exe" %%*
)
if "%INSTALL_EXISTED%"=="1" (
  move "%INSTALL_ROOT%" "%BACKUP_ROOT%" >nul
  if errorlevel 1 goto :install_fail
  set "BACKUP_MOVED=1"
)
if /i "%HEROES_LIKE_INSTALL_FAIL_PHASE%"=="after_backup" (
  echo heroes-like installer: injected after_backup failure 1>&2
  goto :install_fail
)
move "%STAGE_ROOT%" "%INSTALL_ROOT%" >nul
if errorlevel 1 goto :install_fail
set "NEW_COMMITTED=1"

if exist "%LAUNCHER%" (
  move "%LAUNCHER%" "%LAUNCHER_BACKUP%" >nul
  if errorlevel 1 goto :install_fail
)
move "%LAUNCHER_NEW%" "%LAUNCHER%" >nul
if errorlevel 1 goto :install_fail
set "LAUNCHER_PUBLISHED=1"

if exist "%LEGACY_LAUNCHER%" del /f /q "%LEGACY_LAUNCHER%" >nul 2>&1
if exist "%LEGACY_LAUNCHER%" goto :install_fail

rem The new program and launcher are committed. Cleanup failures after this
rem point must never roll back from a partially removed prior backup.
if exist "%BACKUP_ROOT%" rmdir /s /q "%BACKUP_ROOT%"
if exist "%LAUNCHER_BACKUP%" del /f /q "%LAUNCHER_BACKUP%" >nul 2>&1
if exist "%BACKUP_ROOT%" (
  echo heroes-like installer: install committed, but prior backup cleanup failed at "%BACKUP_ROOT%" 1>&2
  exit /b 1
)
if exist "%LAUNCHER_BACKUP%" (
  echo heroes-like installer: install committed, but launcher backup cleanup failed 1>&2
  exit /b 1
)
echo Aurelion Reach installed in %INSTALL_ROOT%
echo Launch from "%LAUNCHER%"
exit /b 0

:install_fail
set "PRIMARY_RC=1"
if "%LAUNCHER_PUBLISHED%"=="1" if exist "%LAUNCHER%" del /f /q "%LAUNCHER%" >nul 2>&1
if exist "%LAUNCHER_BACKUP%" move "%LAUNCHER_BACKUP%" "%LAUNCHER%" >nul 2>&1
if "%NEW_COMMITTED%"=="1" if exist "%INSTALL_ROOT%" (
  move "%INSTALL_ROOT%" "%STAGE_ROOT%" >nul 2>&1
  if exist "%STAGE_ROOT%" rmdir /s /q "%STAGE_ROOT%"
)
if "%BACKUP_MOVED%"=="1" if exist "%BACKUP_ROOT%" (
  move "%BACKUP_ROOT%" "%INSTALL_ROOT%" >nul 2>&1
  if not exist "%INSTALL_ROOT%" (
    echo heroes-like installer: rollback failed; prior install remains at "%BACKUP_ROOT%" 1>&2
    set "PRIMARY_RC=2"
  )
)
if exist "%STAGE_ROOT%" rmdir /s /q "%STAGE_ROOT%"
if exist "%LAUNCHER_NEW%" del /f /q "%LAUNCHER_NEW%" >nul 2>&1
if "%START_MENU_CREATED%"=="1" rmdir "%START_MENU_ROOT%" >nul 2>&1
exit /b %PRIMARY_RC%

:validate_required_payload
setlocal DisableDelayedExpansion
for %%F in (heroes-like.exe heroes-like.pck aurelion_map_persistence.windows.template_release.x86_64.dll README.txt build-info.json install.cmd uninstall.cmd heroes-like-installer-helper.exe) do (
  if not exist "%~1\%%F" (
    echo heroes-like installer: required manifest-owned payload "%%F" is missing 1>&2
    endlocal & exit /b 1
  )
)
endlocal & exit /b 0

:validate_marker
setlocal DisableDelayedExpansion
if not exist "%~1" (
  echo heroes-like installer: install ownership marker is missing 1>&2
  endlocal & exit /b 1
)
set "OWNER="
set /p "OWNER="<"%~1"
if not "%OWNER%"=="heroes-like-user-local-install-v1" (
  echo heroes-like installer: install ownership marker is invalid 1>&2
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
echo heroes-like installer: paths containing ! are not supported 1>&2
exit /b 1

:overlapping_paths
echo heroes-like installer: release payload, install, and Start Menu directories must not overlap 1>&2
exit /b 1

:unsafe_install_root
echo heroes-like installer: refusing unsafe install directory "%INSTALL_ROOT%" 1>&2
exit /b 1

:unsafe_start_menu
echo heroes-like installer: refusing unsafe Start Menu directory "%START_MENU_ROOT%" 1>&2
exit /b 1
