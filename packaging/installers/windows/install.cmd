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

for %%F in (heroes-like.exe heroes-like.pck aurelion_map_persistence.windows.template_release.x86_64.dll README.txt build-info.json release-manifest.json uninstall.cmd) do (
  if not exist "%SOURCE_DIR%%%F" (
    echo heroes-like installer: missing payload %%F 1>&2
    exit /b 1
  )
)

if not exist "%HEROES_LIKE_INSTALL_DIR%" mkdir "%HEROES_LIKE_INSTALL_DIR%"
if errorlevel 1 exit /b 1
if not exist "%HEROES_LIKE_START_MENU_DIR%" mkdir "%HEROES_LIKE_START_MENU_DIR%"
if errorlevel 1 exit /b 1

for %%F in (heroes-like.exe heroes-like.pck aurelion_map_persistence.windows.template_release.x86_64.dll README.txt build-info.json release-manifest.json install.cmd uninstall.cmd) do (
  copy /Y "%SOURCE_DIR%%%F" "%HEROES_LIKE_INSTALL_DIR%\%%F" >nul
  if errorlevel 1 exit /b 1
)
>"%HEROES_LIKE_INSTALL_DIR%\.heroes-like-install" echo heroes-like-user-local-install-v1
if errorlevel 1 exit /b 1

>"%HEROES_LIKE_START_MENU_DIR%\Heroes Like.cmd" echo @echo off
>>"%HEROES_LIKE_START_MENU_DIR%\Heroes Like.cmd" echo start "" "%HEROES_LIKE_INSTALL_DIR%\heroes-like.exe" %%*

echo heroes-like installed in %HEROES_LIKE_INSTALL_DIR%
echo Launch from "%HEROES_LIKE_START_MENU_DIR%\Heroes Like.cmd"
exit /b 0
