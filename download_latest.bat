@echo off
echo ===================================================
echo Updating Codex CLI from GitHub (with local fix)
echo ===================================================
echo.

set "BRANCH=fix/windows-shell-hang-18983"
set "STASH_NAME=download_latest.bat auto-stash"

git rev-parse --verify --quiet REBASE_HEAD >nul 2>nul
if not errorlevel 1 (
    echo Error: a rebase is already in progress.
    echo Run "git rebase --abort" or "git rebase --continue" first, then rerun this script.
    exit /b 1
)

if exist .git\rebase-merge rmdir /s /q .git\rebase-merge
if exist .git\rebase-apply rmdir /s /q .git\rebase-apply

git diff --quiet
if errorlevel 1 (
    git stash push --message "%STASH_NAME%"
    if errorlevel 1 exit /b 1
    set "HAS_STASH=1"
) else (
    set "HAS_STASH=0"
)

:: Ensure we are on the custom fix branch
git switch %BRANCH%
if errorlevel 1 exit /b 1

:: Fetch the latest code from the official repository
git fetch origin
if errorlevel 1 exit /b 1

:: Rebase (re-apply) our local fix on top of the latest main branch
git rebase origin/main
if errorlevel 1 exit /b 1

if "%HAS_STASH%"=="1" (
    git stash pop
    if errorlevel 1 (
        echo Warning: failed to restore the auto-stash. Run "git stash list" and apply "%STASH_NAME%" manually if needed.
        exit /b 1
    )
)

echo.
echo ===================================================
echo Rebuilding Codex CLI...
echo ===================================================
cd codex-rs
cargo build --release --bin codex
cd ..

echo.
echo Update and rebuild complete! Your local fix has been preserved.
pause
