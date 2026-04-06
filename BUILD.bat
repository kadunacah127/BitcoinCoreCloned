@echo off
setlocal

:: ============================================================================
:: Bitcoin Core Windows Build Script - v3.0 (Fixed vcpkg issues)
:: ============================================================================

title Bitcoin Core Builder
color 0A

echo.
echo ============================================================================
echo                    BITCOIN CORE WINDOWS BUILD v3.0
echo ============================================================================
echo.

:: Get the directory where this script is located
set "SOURCE_DIR=%~dp0"
set "SOURCE_DIR=%SOURCE_DIR:~0,-1%"
set "BUILD_DIR=%SOURCE_DIR%\build"
set "VCPKG_DIR=C:\vcpkg"

echo [INFO] Source: %SOURCE_DIR%
echo [INFO] Build:  %BUILD_DIR%
echo [INFO] vcpkg:  %VCPKG_DIR%
echo.

:: Change to source directory
cd /d "%SOURCE_DIR%"

:: Verify source files exist
if not exist "%SOURCE_DIR%\CMakeLists.txt" (
    echo [ERROR] CMakeLists.txt not found
    echo [ERROR] Make sure this script is in the Bitcoin Core root folder
    goto :failed
)
echo [OK] Source files verified
echo.

:: ============================================================================
:: STEP 1: Fix vcpkg
:: ============================================================================
echo [STEP 1/4] Updating and fixing vcpkg...

cd /d "%VCPKG_DIR%"
if errorlevel 1 (
    echo [ERROR] Cannot access vcpkg directory
    goto :failed
)

:: Update vcpkg
echo         Updating vcpkg...
git pull >nul 2>&1
call bootstrap-vcpkg.bat -disableMetrics >nul 2>&1

:: Clear failed packages
echo         Clearing failed package caches...
if exist "%VCPKG_DIR%\buildtrees\libiconv" rmdir /s /q "%VCPKG_DIR%\buildtrees\libiconv" 2>nul
if exist "%VCPKG_DIR%\packages\libiconv_x64-windows-static" rmdir /s /q "%VCPKG_DIR%\packages\libiconv_x64-windows-static" 2>nul
if exist "%VCPKG_DIR%\downloads\*.tmp" del /q "%VCPKG_DIR%\downloads\*.tmp" 2>nul

cd /d "%SOURCE_DIR%"
echo [OK] vcpkg updated
echo.

:: ============================================================================
:: STEP 2: Load Visual Studio (BEFORE any cmake commands)
:: ============================================================================
echo [STEP 2/4] Loading Visual Studio environment...

set "VS_VCVARS="

:: Find vcvars64.bat
for %%p in (
    "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
    "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
    "%ProgramFiles%\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat"
    "%ProgramFiles%\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"
    "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
    "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
) do (
    if exist "%%~p" set "VS_VCVARS=%%~p"
)

if not defined VS_VCVARS (
    echo [ERROR] Visual Studio 2022 not found!
    echo [ERROR] Install Visual Studio 2022 Build Tools with C++ workload
    goto :failed
)

echo         Found: %VS_VCVARS%
echo         Loading environment...

:: Load VS environment
call "%VS_VCVARS%" x64 >nul 2>&1

:: IMPORTANT: Return to source directory after vcvars
cd /d "%SOURCE_DIR%"

:: Verify VS is loaded
where cl.exe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Visual Studio environment failed to load
    goto :failed
)

echo [OK] Visual Studio 2022 loaded
echo.

:: ============================================================================
:: STEP 3: Configure with CMake
:: ============================================================================
echo [STEP 3/4] Configuring build...
echo         This may take 15-45 minutes on first run
echo.

:: Clean old build if exists and had errors
if exist "%BUILD_DIR%\CMakeCache.txt" (
    if exist "%BUILD_DIR%\vcpkg-manifest-install.log" (
        echo         Cleaning previous failed build...
        rmdir /s /q "%BUILD_DIR%" 2>nul
    )
)

:: Set vcpkg environment
set "VCPKG_ROOT=%VCPKG_DIR%"
set "PATH=%VCPKG_DIR%;%PATH%"

:: Run CMake configure
cmake -S "%SOURCE_DIR%" -B "%BUILD_DIR%" -G "Visual Studio 17 2022" -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_DIR%/scripts/buildsystems/vcpkg.cmake" -DVCPKG_TARGET_TRIPLET=x64-windows-static -DBUILD_GUI=OFF -DBUILD_TESTS=OFF -DBUILD_BENCH=OFF -DWITH_ZMQ=OFF -DENABLE_WALLET=ON -DVCPKG_INSTALL_OPTIONS="--clean-after-build"

if errorlevel 1 (
    echo.
    echo [ERROR] Configuration failed
    echo.
    echo [TIP] Try these fixes:
    echo       1. Run this script again (retry often works)
    echo       2. Delete C:\vcpkg\buildtrees and C:\vcpkg\downloads folders
    echo       3. Disable antivirus temporarily
    echo       4. Check internet connection
    goto :failed
)

echo.
echo [OK] Configuration complete
echo.

:: ============================================================================
:: STEP 4: Build
:: ============================================================================
echo [STEP 4/4] Building Bitcoin Core...
echo         This may take 15-30 minutes
echo.

cmake --build "%BUILD_DIR%" --config Release --parallel 8

if errorlevel 1 (
    echo.
    echo [ERROR] Build failed
    goto :failed
)

:: ============================================================================
:: SUCCESS
:: ============================================================================
echo.
echo ============================================================================
echo                         BUILD SUCCESSFUL!
echo ============================================================================
echo.
echo Your executables are in:
echo.

set "EXE_DIR="
if exist "%BUILD_DIR%\src\Release\bitcoind.exe" set "EXE_DIR=%BUILD_DIR%\src\Release"
if exist "%BUILD_DIR%\bin\Release\bitcoind.exe" set "EXE_DIR=%BUILD_DIR%\bin\Release"

if defined EXE_DIR (
    echo %EXE_DIR%
    echo.
    echo Files:
    dir /b "%EXE_DIR%\*.exe" 2>nul
) else (
    echo %BUILD_DIR%
    echo.
    echo Look in build\src\Release or build\bin\Release
)

echo.
echo ============================================================================
goto :end

:failed
echo.
echo ============================================================================
echo                           BUILD FAILED
echo ============================================================================
echo.
echo Quick fixes to try:
echo.
echo 1. DELETE these folders and run again:
echo    - C:\vcpkg\buildtrees
echo    - C:\vcpkg\downloads  
echo    - %BUILD_DIR%
echo.
echo 2. UPDATE vcpkg manually:
echo    cd C:\vcpkg
echo    git pull
echo    bootstrap-vcpkg.bat
echo.
echo 3. DISABLE antivirus/firewall temporarily
echo.
echo 4. RUN as Administrator
echo.

:end
echo.
pause
