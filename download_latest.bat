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

:: Fetch the latest code and tags from the official repository
git fetch origin --tags
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

:: Detect version from latest stable rust-v* tag
set "CARGO_TOML=Cargo.toml"
FOR /F "tokens=*" %%T IN ('powershell -Command "git tag --sort=-version:refname | Where-Object { $_ -match '^rust-v\d' -and $_ -notmatch 'alpha|beta|rc' } | Select-Object -First 1"') DO SET "LATEST_TAG=%%T"
if defined LATEST_TAG (
    set "CUSTOM_VERSION=%LATEST_TAG:rust-v=%-local"
) else (
    set "CUSTOM_VERSION=0.0.0-local"
    echo Warning: could not detect version from tags, using 0.0.0-local.
)
echo Stamping version: %CUSTOM_VERSION%
powershell -Command "(Get-Content '%CARGO_TOML%') -replace 'version = \"0\.0\.0\"', 'version = \"%CUSTOM_VERSION%\"' | Set-Content '%CARGO_TOML%'"
if errorlevel 1 (
    echo Warning: could not patch version in %CARGO_TOML%. Continuing with 0.0.0.
)

cargo build --release -p codex-cli
set BUILD_ERR=%errorlevel%

:: Restore version to 0.0.0 so git stays clean
powershell -Command "(Get-Content '%CARGO_TOML%') -replace 'version = \"[^\"]+\"', 'version = \"0.0.0\"' | Set-Content '%CARGO_TOML%' -NoNewline:$false"

cd ..
if %BUILD_ERR% neq 0 exit /b %BUILD_ERR%

echo.
echo Update and rebuild complete! Your local fix has been preserved.
pause
