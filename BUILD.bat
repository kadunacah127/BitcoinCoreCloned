@echo off
setlocal

:: ============================================================================
:: Bitcoin Core Windows Build Script - SIMPLE VERSION
:: ============================================================================

title Bitcoin Core Builder
color 0A

echo.
echo ============================================================================
echo                    BITCOIN CORE WINDOWS BUILD
echo ============================================================================
echo.

:: Get the directory where this script is located
set "SOURCE_DIR=%~dp0"
set "SOURCE_DIR=%SOURCE_DIR:~0,-1%"
set "BUILD_DIR=%SOURCE_DIR%\build"
set "VCPKG_DIR=C:\vcpkg"
set "BUILDTREES=C:\vbt"

echo [INFO] Source: %SOURCE_DIR%
echo [INFO] Build:  %BUILD_DIR%
echo [INFO] vcpkg:  %VCPKG_DIR%
echo.

:: Change to source directory
cd /d "%SOURCE_DIR%"
if errorlevel 1 (
    echo [ERROR] Cannot access source directory
    goto :failed
)

:: Verify source files exist
if not exist "%SOURCE_DIR%\CMakeLists.txt" (
    echo [ERROR] CMakeLists.txt not found
    echo [ERROR] Make sure this script is in the Bitcoin Core root folder
    goto :failed
)
echo [OK] Source files verified
echo.

:: Load Visual Studio environment
echo [STEP 1/3] Loading Visual Studio environment...

set "VS_PATH="
for %%p in (
    "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
    "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
    "%ProgramFiles%\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat"
    "%ProgramFiles%\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"
    "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
) do (
    if exist "%%~p" set "VS_PATH=%%~p"
)

if not defined VS_PATH (
    echo [ERROR] Visual Studio 2022 not found
    goto :failed
)

call "%VS_PATH%" x64 >nul 2>&1
cd /d "%SOURCE_DIR%"
echo [OK] Visual Studio loaded
echo.

:: Configure
echo [STEP 2/3] Configuring build (this may take 15-45 minutes first time)...
echo.

if not exist "%BUILDTREES%" mkdir "%BUILDTREES%"

cmake -S "%SOURCE_DIR%" -B "%BUILD_DIR%" -G "Visual Studio 17 2022" -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_DIR%/scripts/buildsystems/vcpkg.cmake" -DVCPKG_TARGET_TRIPLET=x64-windows-static -DBUILD_GUI=OFF -DBUILD_TESTS=OFF -DBUILD_BENCH=OFF -DWITH_ZMQ=OFF -DENABLE_WALLET=ON

if errorlevel 1 (
    echo.
    echo [ERROR] Configuration failed
    goto :failed
)

echo.
echo [OK] Configuration complete
echo.

:: Build
echo [STEP 3/3] Building (this may take 15-30 minutes)...
echo.

cmake --build "%BUILD_DIR%" --config Release --parallel 8

if errorlevel 1 (
    echo.
    echo [ERROR] Build failed
    goto :failed
)

echo.
echo ============================================================================
echo                         BUILD SUCCESSFUL!
echo ============================================================================
echo.
echo Your executables are in:
echo %BUILD_DIR%\src\Release\
echo.
dir "%BUILD_DIR%\src\Release\*.exe" 2>nul
echo.
echo ============================================================================
goto :end

:failed
echo.
echo ============================================================================
echo                           BUILD FAILED
echo ============================================================================
echo.

:end
echo.
pause
