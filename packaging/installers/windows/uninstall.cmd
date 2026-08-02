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
if not exist "%HEROES_LIKE_INSTALL_DIR%\.heroes-like-install" (
  echo heroes-like uninstaller: install ownership marker is missing 1>&2
  exit /b 1
)

del /F /Q "%HEROES_LIKE_START_MENU_DIR%\Heroes Like.cmd" >nul 2>&1
rmdir "%HEROES_LIKE_START_MENU_DIR%" >nul 2>&1
cd /d "%TEMP%"
rmdir /S /Q "%HEROES_LIKE_INSTALL_DIR%"
if exist "%HEROES_LIKE_INSTALL_DIR%" exit /b 1

echo heroes-like program files removed
echo Saved games, settings, generated maps, and runtime logs were preserved.
exit /b 0
