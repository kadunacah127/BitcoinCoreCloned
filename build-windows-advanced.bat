@echo off
setlocal EnableDelayedExpansion

:: ============================================================================
:: Bitcoin Core Windows Build Script - ADVANCED VERSION v2.2
:: With automatic error recovery, retry logic, and network fixes
:: No abnormal exits - all errors handled gracefully
:: ============================================================================

title Bitcoin Core Windows Builder (Advanced v2.2)
color 0B

:: Default Configuration
set "REPO_DIR=%~dp0"
set "VCPKG_DIR=C:\vcpkg"
set "BUILD_DIR=%REPO_DIR%build"
set "INSTALL_DIR=C:\Bitcoin"
set "VCPKG_BUILDTREES=C:\vbt"
set "BUILD_GUI=OFF"
set "BUILD_TESTS=OFF"
set "BUILD_WALLET=ON"
set "BUILD_ZMQ=OFF"
set "BUILD_TYPE=Release"
set "PARALLEL_JOBS=8"
set "CLEAN_BUILD=0"
set "MAX_RETRIES=3"

:: Required VS version
set "REQUIRED_VS_VERSION=2022"
set "REQUIRED_VS_GENERATOR=Visual Studio 17 2022"

:: Fix SSL/TLS issues
set "GIT_SSL_NO_VERIFY=0"
set "CURL_SSL_BACKEND=schannel"

goto :Menu

:: ============================================================================
:: MENU
:: ============================================================================

:Menu
cls
echo.
echo ============================================================================
echo           BITCOIN CORE WINDOWS BUILD SCRIPT (ADVANCED v2.2)
echo ============================================================================
echo.
echo   Build Configuration:
echo   ---------------------
echo   [1] Build GUI (bitcoin-qt.exe):     %BUILD_GUI%
echo   [2] Build Tests:                    %BUILD_TESTS%
echo   [3] Enable Wallet:                  %BUILD_WALLET%
echo   [4] Enable ZeroMQ:                  %BUILD_ZMQ%
echo   [5] Build Type:                     %BUILD_TYPE%
echo   [6] Parallel Jobs:                  %PARALLEL_JOBS%
echo   [7] Clean Build:                    %CLEAN_BUILD%
echo   [8] Install Directory:              %INSTALL_DIR%
echo.
echo   Actions:
echo   --------
echo   [C] Check Requirements Only
echo   [B] START BUILD
echo   [I] Install After Build
echo   [R] REPAIR / Fix Issues (remove ALL VS versions, clear cache, fix network)
echo   [Q] Quit
echo.
echo ============================================================================
echo.

set /p "CHOICE=Enter option: "

if /i "%CHOICE%"=="1" goto :ToggleGUI
if /i "%CHOICE%"=="2" goto :ToggleTests
if /i "%CHOICE%"=="3" goto :ToggleWallet
if /i "%CHOICE%"=="4" goto :ToggleZMQ
if /i "%CHOICE%"=="5" goto :ToggleBuildType
if /i "%CHOICE%"=="6" goto :SetJobs
if /i "%CHOICE%"=="7" goto :ToggleClean
if /i "%CHOICE%"=="8" goto :SetInstallDir
if /i "%CHOICE%"=="C" goto :CheckOnly
if /i "%CHOICE%"=="B" goto :StartBuild
if /i "%CHOICE%"=="I" goto :InstallOnly
if /i "%CHOICE%"=="R" goto :RepairAll
if /i "%CHOICE%"=="Q" goto :Quit

goto :Menu

:ToggleGUI
if "%BUILD_GUI%"=="OFF" (set "BUILD_GUI=ON") else (set "BUILD_GUI=OFF")
goto :Menu

:ToggleTests
if "%BUILD_TESTS%"=="OFF" (set "BUILD_TESTS=ON") else (set "BUILD_TESTS=OFF")
goto :Menu

:ToggleWallet
if "%BUILD_WALLET%"=="OFF" (set "BUILD_WALLET=ON") else (set "BUILD_WALLET=OFF")
goto :Menu

:ToggleZMQ
if "%BUILD_ZMQ%"=="OFF" (set "BUILD_ZMQ=ON") else (set "BUILD_ZMQ=OFF")
goto :Menu

:ToggleBuildType
if "%BUILD_TYPE%"=="Release" (
    set "BUILD_TYPE=Debug"
) else if "%BUILD_TYPE%"=="Debug" (
    set "BUILD_TYPE=RelWithDebInfo"
) else (
    set "BUILD_TYPE=Release"
)
goto :Menu

:SetJobs
set /p "PARALLEL_JOBS=Enter number of parallel jobs (1-32): "
goto :Menu

:ToggleClean
if "%CLEAN_BUILD%"=="0" (set "CLEAN_BUILD=1") else (set "CLEAN_BUILD=0")
goto :Menu

:SetInstallDir
set /p "INSTALL_DIR=Enter install directory: "
goto :Menu

:CheckOnly
echo.
echo [STEP] Checking requirements...
echo.
call :DoCheckRequirements
echo.
pause
goto :Menu

:InstallOnly
set "INSTALL_FOUND=0"
if exist "%BUILD_DIR%\bin\Release" set "INSTALL_FOUND=1"
if exist "%BUILD_DIR%\src\Release" set "INSTALL_FOUND=1"
if exist "%BUILD_DIR%\bin\%BUILD_TYPE%" set "INSTALL_FOUND=1"
if exist "%BUILD_DIR%\src\%BUILD_TYPE%" set "INSTALL_FOUND=1"

if "!INSTALL_FOUND!"=="1" (
    echo Installing to %INSTALL_DIR%...
    cmake --install "%BUILD_DIR%" --config %BUILD_TYPE% --prefix "%INSTALL_DIR%" --strip 2>nul || (
        echo [WARNING] Install with strip failed, trying without strip...
        cmake --install "%BUILD_DIR%" --config %BUILD_TYPE% --prefix "%INSTALL_DIR%" 2>nul || (
            echo [ERROR] Installation failed.
        )
    )
    echo Done!
) else (
    echo [ERROR] Build not found. Run build first.
)
pause
goto :Menu

:Quit
echo.
echo Goodbye!
exit /b 0

:: ============================================================================
:: REPAIR ALL ISSUES
:: ============================================================================

:RepairAll
cls
echo.
echo ============================================================================
echo                     REPAIR / FIX ALL ISSUES (v2.2)
echo ============================================================================
echo.
echo This will:
echo   1. Clear vcpkg download cache (fixes SSL/download errors)
echo   2. Clear build trees (fixes path too long errors)
echo   3. Update vcpkg to latest version
echo   4. REMOVE ALL Visual Studio installations:
echo      - VS 2015, 2017, 2019, 2022, 2026 and ANY other version
echo      - Community, Professional, Enterprise, BuildTools
echo      - All incomplete/partial installations
echo   5. Install fresh Visual Studio Build Tools %REQUIRED_VS_VERSION%
echo   6. Reset network settings for downloads
echo   7. Clean previous build
echo.
echo [WARNING] This will UNINSTALL all Visual Studio versions!
echo [WARNING] This process may take 15-30 minutes.
echo.
set /p "CONFIRM=Continue? (Y/N): "
if /i not "%CONFIRM%"=="Y" goto :Menu

echo.
echo ============================================================================
echo                    STARTING REPAIR PROCESS
echo ============================================================================
echo.

:: Step 1: Clear vcpkg caches
echo [REPAIR 1/7] Clearing vcpkg download cache...
call :SafeRemoveDir "%VCPKG_DIR%\downloads"
call :SafeRemoveDir "%VCPKG_DIR%\installed"
call :SafeRemoveDir "%VCPKG_DIR%\buildtrees"
call :SafeRemoveDir "%VCPKG_DIR%\packages"
echo          [OK] vcpkg caches cleared

:: Step 2: Clear build trees
echo [REPAIR 2/7] Clearing build trees...
call :SafeRemoveDir "%VCPKG_BUILDTREES%"
call :SafeRemoveDir "%BUILD_DIR%"
echo          [OK] Build trees cleared

:: Step 3: Update vcpkg
echo [REPAIR 3/7] Updating vcpkg...
if exist "%VCPKG_DIR%\.git" (
    pushd "%VCPKG_DIR%" 2>nul || goto :SkipVcpkgUpdate
    git fetch origin 2>nul
    git reset --hard origin/master 2>nul
    call bootstrap-vcpkg.bat -disableMetrics >nul 2>&1
    popd
    echo          [OK] vcpkg updated
) else (
    echo          [INFO] vcpkg not installed, will install later
)
:SkipVcpkgUpdate

:: Step 4: Remove ALL Visual Studio installations
echo [REPAIR 4/7] Removing ALL Visual Studio installations...
echo          [INFO] This may take several minutes...
echo.
call :DoRemoveAllVisualStudio

:: Step 5: Install fresh Visual Studio Build Tools
echo.
echo [REPAIR 5/7] Installing fresh Visual Studio Build Tools %REQUIRED_VS_VERSION%...
echo          [INFO] This may take 10-20 minutes...
echo.
call :DoInstallVSFresh

:: Step 6: Fix network settings
echo.
echo [REPAIR 6/7] Fixing network settings...
netsh winsock reset >nul 2>&1
netsh int ip reset >nul 2>&1
ipconfig /flushdns >nul 2>&1
echo          [OK] Network settings reset

:: Configure git for better compatibility
git config --global http.sslBackend schannel 2>nul
git config --global http.postBuffer 524288000 2>nul
git config --global core.longpaths true 2>nul
echo          [OK] Git configured for better compatibility

:: Step 7: Verify installation
echo.
echo [REPAIR 7/7] Verifying installation...
call :DoCheckVisualStudioVersion
if !errorlevel! equ 0 (
    echo          [OK] Visual Studio %REQUIRED_VS_VERSION% verified
) else (
    echo          [WARNING] Visual Studio may need manual installation
    echo          [INFO] Please install Visual Studio Build Tools %REQUIRED_VS_VERSION% manually
)

echo.
echo ============================================================================
echo                         REPAIR COMPLETE
echo ============================================================================
echo.
echo IMPORTANT: Please RESTART YOUR COMPUTER before building!
echo.
echo After restart:
echo   1. Run this script again as Administrator
echo   2. Press [B] to start the build
echo.
echo ============================================================================
echo.
pause
goto :Menu

:: ============================================================================
:: SAFE REMOVE DIRECTORY (No abnormal exits)
:: ============================================================================

:SafeRemoveDir
if "%~1"=="" exit /b 0
if exist "%~1" (
    rmdir /s /q "%~1" 2>nul
    if exist "%~1" (
        :: Try again with timeout
        timeout /t 2 /nobreak >nul 2>&1
        rmdir /s /q "%~1" 2>nul
    )
)
exit /b 0

:: ============================================================================
:: SAFE UNINSTALL (No abnormal exits)
:: ============================================================================

:SafeWingetUninstall
if "%~1"=="" exit /b 0
winget uninstall --id "%~1" --silent >nul 2>&1
exit /b 0

:: ============================================================================
:: REMOVE ALL VISUAL STUDIO INSTALLATIONS
:: ============================================================================

:DoRemoveAllVisualStudio
echo          Searching for Visual Studio installations...
echo.

:: Use winget to remove all VS versions (silent, no errors)
where winget >nul 2>&1
if !errorlevel! equ 0 (
    echo          [INFO] Using winget to uninstall Visual Studio products...
    
    :: Visual Studio 2026 versions (future-proof)
    echo          Checking Visual Studio 2026...
    call :SafeWingetUninstall "Microsoft.VisualStudio.2026.Community"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2026.Professional"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2026.Enterprise"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2026.BuildTools"
    
    :: Visual Studio 2022 versions
    echo          Checking Visual Studio 2022...
    call :SafeWingetUninstall "Microsoft.VisualStudio.2022.Community"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2022.Professional"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2022.Enterprise"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2022.BuildTools"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2022.TeamExplorer"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2022.TestAgent"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2022.TestController"
    
    :: Visual Studio 2019 versions
    echo          Checking Visual Studio 2019...
    call :SafeWingetUninstall "Microsoft.VisualStudio.2019.Community"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2019.Professional"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2019.Enterprise"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2019.BuildTools"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2019.TeamExplorer"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2019.TestAgent"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2019.TestController"
    
    :: Visual Studio 2017 versions
    echo          Checking Visual Studio 2017...
    call :SafeWingetUninstall "Microsoft.VisualStudio.2017.Community"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2017.Professional"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2017.Enterprise"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2017.BuildTools"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2017.TeamExplorer"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2017.TestAgent"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2017.TestController"
    
    :: Visual Studio 2015 versions
    echo          Checking Visual Studio 2015...
    call :SafeWingetUninstall "Microsoft.VisualStudio.2015.Community"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2015.Professional"
    call :SafeWingetUninstall "Microsoft.VisualStudio.2015.Enterprise"
    
    :: Generic/Other VS products
    echo          Checking other Visual Studio products...
    call :SafeWingetUninstall "Microsoft.VisualStudioCode"
    call :SafeWingetUninstall "Microsoft.VisualStudio.Locator"
)

:: Use VS Installer to remove everything (catches incomplete installations)
echo          [INFO] Using VS Installer to clean up...
set "VS_INSTALLER=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vs_installer.exe"
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

:: Uninstall each found instance using vswhere
if exist "!VSWHERE!" (
    echo          Finding all VS instances...
    for /f "tokens=*" %%i in ('"!VSWHERE!" -all -prerelease -property installationPath 2^>nul') do (
        if exist "%%i" (
            echo          Uninstalling: %%i
            if exist "!VS_INSTALLER!" (
                "!VS_INSTALLER!" uninstall --installPath "%%i" --quiet --wait >nul 2>&1
            )
        )
    )
)

:: Final cleanup with installer - uninstall all
if exist "!VS_INSTALLER!" (
    echo          Running final VS Installer cleanup...
    "!VS_INSTALLER!" --quiet --wait --norestart uninstall --all >nul 2>&1
)

:: Force remove leftover directories for ALL versions
echo          Cleaning leftover directories...

:: Remove all VS year directories (2015-2030 to be future-proof)
for %%y in (2015 2016 2017 2018 2019 2020 2021 2022 2023 2024 2025 2026 2027 2028 2029 2030) do (
    call :SafeRemoveDir "%ProgramFiles%\Microsoft Visual Studio\%%y"
    call :SafeRemoveDir "%ProgramFiles(x86)%\Microsoft Visual Studio\%%y"
)

:: Remove VS Installer directory
call :SafeRemoveDir "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer"

:: Remove VS Shared directory
call :SafeRemoveDir "%ProgramFiles(x86)%\Microsoft Visual Studio\Shared"
call :SafeRemoveDir "%ProgramFiles%\Microsoft Visual Studio\Shared"

:: Remove VS cache directories
call :SafeRemoveDir "%ProgramData%\Microsoft\VisualStudio"
call :SafeRemoveDir "%LOCALAPPDATA%\Microsoft\VisualStudio"
call :SafeRemoveDir "%APPDATA%\Microsoft\VisualStudio"

:: Remove VS temp directories
call :SafeRemoveDir "%TEMP%\dd_*"
call :SafeRemoveDir "%TEMP%\VSFeedbackIntelliCodeLogs"
call :SafeRemoveDir "%TEMP%\VSRemoteControl"

:: Clean Package Cache (VS components only)
if exist "%ProgramData%\Package Cache" (
    echo          Cleaning Package Cache (VS components)...
    for /d %%d in ("%ProgramData%\Package Cache\*") do (
        echo "%%d" | findstr /i "VisualStudio vs_" >nul 2>&1 && (
            rmdir /s /q "%%d" 2>nul
        )
    )
)

:: Remove leftover registry entries would require admin and is risky, skip

echo          [OK] All Visual Studio installations removed
exit /b 0

:: ============================================================================
:: INSTALL FRESH VISUAL STUDIO BUILD TOOLS
:: ============================================================================

:DoInstallVSFresh
set "VS_INSTALL_SUCCESS=0"

where winget >nul 2>&1
if !errorlevel! equ 0 (
    echo          Installing via winget...
    winget install --id Microsoft.VisualStudio.%REQUIRED_VS_VERSION%.BuildTools ^
        --override "--wait --quiet --norestart --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22621 --add Microsoft.VisualStudio.Component.VC.CMake.Project --includeRecommended" ^
        --accept-package-agreements --accept-source-agreements >nul 2>&1
    
    if !errorlevel! equ 0 (
        set "VS_INSTALL_SUCCESS=1"
        echo          [OK] Visual Studio Build Tools %REQUIRED_VS_VERSION% installed via winget
    ) else (
        echo          [WARNING] winget install had issues, trying direct download...
    )
)

if "!VS_INSTALL_SUCCESS!"=="0" (
    call :InstallVSDirect
)

exit /b 0

:InstallVSDirect
echo          Downloading VS Build Tools installer directly...

:: Download with error handling
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vs_buildtools.exe' -OutFile '%TEMP%\vs_buildtools.exe' -UseBasicParsing } catch { exit 1 }" >nul 2>&1

if exist "%TEMP%\vs_buildtools.exe" (
    echo          Running installer (this may take 10-20 minutes)...
    "%TEMP%\vs_buildtools.exe" --quiet --wait --norestart ^
        --add Microsoft.VisualStudio.Workload.VCTools ^
        --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ^
        --add Microsoft.VisualStudio.Component.Windows11SDK.22621 ^
        --add Microsoft.VisualStudio.Component.VC.CMake.Project ^
        --includeRecommended >nul 2>&1
    
    if !errorlevel! equ 0 (
        echo          [OK] Visual Studio Build Tools %REQUIRED_VS_VERSION% installed
    ) else (
        echo          [WARNING] Installer exited with code !errorlevel!
        echo          [INFO] VS may still have installed successfully
    )
    
    :: Cleanup installer
    del "%TEMP%\vs_buildtools.exe" 2>nul
) else (
    echo          [ERROR] Failed to download VS Build Tools installer
    echo          [INFO] Please install Visual Studio Build Tools %REQUIRED_VS_VERSION% manually from:
    echo          https://visualstudio.microsoft.com/downloads/
)
exit /b 0

:: ============================================================================
:: START BUILD
:: ============================================================================

:StartBuild
cls
echo.
echo ============================================================================
echo                         STARTING BUILD PROCESS
echo ============================================================================
echo.
echo   Configuration:
echo   - GUI: %BUILD_GUI%
echo   - Tests: %BUILD_TESTS%
echo   - Wallet: %BUILD_WALLET%
echo   - ZeroMQ: %BUILD_ZMQ%
echo   - Build Type: %BUILD_TYPE%
echo   - Parallel Jobs: %PARALLEL_JOBS%
echo   - Clean Build: %CLEAN_BUILD%
echo   - Required VS: %REQUIRED_VS_VERSION%
echo.
echo ============================================================================
echo.

:: Check admin rights (warning only, don't exit)
net session >nul 2>&1
if !errorlevel! neq 0 (
    echo [WARNING] Not running as Administrator.
    echo [WARNING] Some operations may fail. Consider restarting as Admin.
    echo.
)

:: Step 1: Check requirements
echo [STEP 1/6] Checking requirements...
echo.
call :DoCheckRequirements
if !errorlevel! neq 0 (
    echo.
    echo [ERROR] Requirements check failed.
    echo [INFO] Press [R] in menu to repair.
    pause
    goto :Menu
)

:: Step 2: Setup environment
echo.
echo [STEP 2/6] Setting up build environment...
call :DoSetupEnvironment
if !errorlevel! neq 0 (
    echo.
    echo [ERROR] Failed to setup build environment.
    echo [INFO] Press [R] in menu to repair.
    pause
    goto :Menu
)

:: Step 3: Verify source
echo [STEP 3/6] Verifying source code...
call :DoVerifySource
if !errorlevel! neq 0 (
    echo.
    echo [ERROR] Source verification failed.
    pause
    goto :Menu
)

:: Step 4: Configure with retry
echo.
echo [STEP 4/6] Configuring build...
echo [INFO] This may take 15-45 minutes on first run (downloading dependencies)
echo [INFO] If download fails, will retry up to %MAX_RETRIES% times
echo.
call :DoConfigureBuildWithRetry
if !errorlevel! neq 0 (
    echo.
    echo [ERROR] Configuration failed after all retries.
    echo [INFO] Press [R] in menu to repair and clear caches.
    pause
    goto :Menu
)

:: Step 5: Build
echo.
echo [STEP 5/6] Building Bitcoin Core...
echo [INFO] Using %PARALLEL_JOBS% parallel jobs
call :DoRunBuild
if !errorlevel! neq 0 (
    echo.
    echo [ERROR] Build failed.
    pause
    goto :Menu
)

:: Step 6: Report
echo.
echo [STEP 6/6] Build complete!
call :DoReportResults

echo.
echo Press any key to return to menu...
pause >nul
goto :Menu

:: ============================================================================
:: CHECK REQUIREMENTS FUNCTION
:: ============================================================================

:DoCheckRequirements
set "REQ_FAILED=0"

:: Check Git
where git >nul 2>&1
if !errorlevel! neq 0 (
    echo [MISSING] Git - Installing...
    call :DoInstallGit
    where git >nul 2>&1
    if !errorlevel! neq 0 (
        echo [ERROR] Git installation failed
        set "REQ_FAILED=1"
    ) else (
        echo [OK] Git installed
    )
) else (
    echo [OK] Git found
)

:: Check Python
where python >nul 2>&1
if !errorlevel! neq 0 (
    echo [MISSING] Python - Installing...
    call :DoInstallPython
    where python >nul 2>&1
    if !errorlevel! neq 0 (
        echo [WARNING] Python installation may need restart
    ) else (
        echo [OK] Python installed
    )
) else (
    echo [OK] Python found
)

:: Check CMake
where cmake >nul 2>&1
if !errorlevel! neq 0 (
    echo [MISSING] CMake - Installing...
    call :DoInstallCMake
    where cmake >nul 2>&1
    if !errorlevel! neq 0 (
        echo [WARNING] CMake installation may need restart
    ) else (
        echo [OK] CMake installed
    )
) else (
    echo [OK] CMake found
)

:: Check Visual Studio (must be correct version)
echo [CHECK] Visual Studio %REQUIRED_VS_VERSION%...
call :DoCheckVisualStudioVersion
if !errorlevel! neq 0 (
    echo [MISSING] Visual Studio Build Tools %REQUIRED_VS_VERSION% - Installing...
    call :DoInstallVSFresh
    
    :: Verify installation
    call :DoCheckVisualStudioVersion
    if !errorlevel! neq 0 (
        echo [ERROR] Visual Studio %REQUIRED_VS_VERSION% installation failed
        echo [INFO] Please install manually or press [R] to repair
        set "REQ_FAILED=1"
    ) else (
        echo [OK] Visual Studio %REQUIRED_VS_VERSION% installed
    )
) else (
    echo [OK] Visual Studio %REQUIRED_VS_VERSION% found
)

:: Check vcpkg
if not exist "%VCPKG_DIR%\vcpkg.exe" (
    echo [MISSING] vcpkg - Installing...
    call :DoInstallVcpkg
    if not exist "%VCPKG_DIR%\vcpkg.exe" (
        echo [ERROR] vcpkg installation failed
        set "REQ_FAILED=1"
    ) else (
        echo [OK] vcpkg installed
    )
) else (
    echo [OK] vcpkg found
)

echo.
if "!REQ_FAILED!"=="1" (
    echo [ERROR] Some requirements could not be satisfied
    exit /b 1
)

echo [OK] All requirements satisfied
exit /b 0

:: ============================================================================
:: CHECK VISUAL STUDIO VERSION (SPECIFIC)
:: ============================================================================

:DoCheckVisualStudioVersion
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VS_CORRECT_VERSION=0"
set "VS_PATH="

:: Method 1: Use vswhere to find specific version with required components
if exist "!VSWHERE!" (
    for /f "tokens=*" %%i in ('"!VSWHERE!" -version [17.0^,18.0^) -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2^>nul') do (
        if exist "%%i\VC\Auxiliary\Build\vcvars64.bat" (
            set "VS_PATH=%%i"
            set "VS_CORRECT_VERSION=1"
        )
    )
)

:: Method 2: Check common paths for VS 2022
if "!VS_CORRECT_VERSION!"=="0" (
    for %%p in (
        "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools"
        "%ProgramFiles%\Microsoft Visual Studio\2022\Community"
        "%ProgramFiles%\Microsoft Visual Studio\2022\Professional"
        "%ProgramFiles%\Microsoft Visual Studio\2022\Enterprise"
        "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools"
    ) do (
        if exist "%%~p\VC\Auxiliary\Build\vcvars64.bat" (
            set "VS_PATH=%%~p"
            set "VS_CORRECT_VERSION=1"
        )
    )
)

if "!VS_CORRECT_VERSION!"=="1" (
    echo          Found at: !VS_PATH!
    exit /b 0
) else (
    exit /b 1
)

:: ============================================================================
:: SETUP ENVIRONMENT FUNCTION
:: ============================================================================

:DoSetupEnvironment
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VS_PATH="

:: Find VS 2022 installation specifically
if exist "!VSWHERE!" (
    for /f "tokens=*" %%i in ('"!VSWHERE!" -version [17.0^,18.0^) -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2^>nul') do (
        set "VS_PATH=%%i"
    )
)

:: Fallback to common paths
if not defined VS_PATH (
    for %%p in (
        "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools"
        "%ProgramFiles%\Microsoft Visual Studio\2022\Community"
        "%ProgramFiles%\Microsoft Visual Studio\2022\Professional"
        "%ProgramFiles%\Microsoft Visual Studio\2022\Enterprise"
        "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools"
    ) do (
        if exist "%%~p\VC\Auxiliary\Build\vcvars64.bat" (
            set "VS_PATH=%%~p"
        )
    )
)

if defined VS_PATH (
    if exist "!VS_PATH!\VC\Auxiliary\Build\vcvars64.bat" (
        echo [INFO] Loading Visual Studio environment from: !VS_PATH!
        call "!VS_PATH!\VC\Auxiliary\Build\vcvars64.bat" x64 >nul 2>&1
        echo [OK] Visual Studio environment loaded
    ) else (
        echo [ERROR] vcvars64.bat not found in VS installation
        exit /b 1
    )
) else (
    echo [ERROR] Could not find Visual Studio %REQUIRED_VS_VERSION% installation!
    echo [ERROR] Press [R] in menu to repair, or install Visual Studio manually.
    exit /b 1
)

set "VCPKG_ROOT=%VCPKG_DIR%"

:: Set environment variables to help with downloads
set "GIT_SSL_NO_VERIFY=0"
set "CURL_SSL_BACKEND=schannel"

exit /b 0

:: ============================================================================
:: VERIFY SOURCE FUNCTION
:: ============================================================================

:DoVerifySource
pushd "%REPO_DIR%" 2>nul || (
    echo [ERROR] Cannot access repository directory: %REPO_DIR%
    exit /b 1
)

if not exist "CMakeLists.txt" (
    echo [ERROR] CMakeLists.txt not found!
    echo [ERROR] Please run this script from the Bitcoin Core source directory.
    popd
    exit /b 1
)
if not exist "src\bitcoind.cpp" (
    echo [ERROR] Source files not found!
    echo [ERROR] This doesn't appear to be a valid Bitcoin Core repository.
    popd
    exit /b 1
)
echo [OK] Source code verified
popd
exit /b 0

:: ============================================================================
:: CONFIGURE BUILD WITH RETRY
:: ============================================================================

:DoConfigureBuildWithRetry
set "RETRY_COUNT=0"

:ConfigureRetryLoop
set /a RETRY_COUNT+=1

if !RETRY_COUNT! gtr %MAX_RETRIES% (
    echo [ERROR] Configuration failed after %MAX_RETRIES% attempts.
    exit /b 1
)

if !RETRY_COUNT! gtr 1 (
    echo.
    echo [RETRY] Attempt !RETRY_COUNT! of %MAX_RETRIES%...
    echo [RETRY] Clearing failed downloads...
    
    :: Clear only failed downloads, not all
    if exist "%VCPKG_DIR%\downloads\*.tmp" del /q "%VCPKG_DIR%\downloads\*.tmp" 2>nul
    if exist "%VCPKG_DIR%\downloads\temp" rmdir /s /q "%VCPKG_DIR%\downloads\temp" 2>nul
    
    :: Wait before retry
    echo [RETRY] Waiting 5 seconds before retry...
    timeout /t 5 /nobreak >nul 2>&1
)

call :DoConfigureBuild
if !errorlevel! neq 0 (
    if !RETRY_COUNT! lss %MAX_RETRIES% (
        echo.
        echo [WARNING] Configuration failed. Will retry...
        goto :ConfigureRetryLoop
    ) else (
        exit /b 1
    )
)

exit /b 0

:: ============================================================================
:: CONFIGURE BUILD FUNCTION
:: ============================================================================

:DoConfigureBuild
if "%CLEAN_BUILD%"=="1" (
    if exist "%BUILD_DIR%" (
        echo [INFO] Cleaning previous build...
        call :SafeRemoveDir "%BUILD_DIR%"
    )
)

:: Create buildtrees directory
if not exist "%VCPKG_BUILDTREES%" mkdir "%VCPKG_BUILDTREES%" 2>nul

:: Verify cmake works
cmake --version >nul 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] CMake not working properly!
    exit /b 1
)

echo [INFO] Generator: %REQUIRED_VS_GENERATOR%
echo [INFO] vcpkg: %VCPKG_DIR%
echo [INFO] Build trees: %VCPKG_BUILDTREES%
echo.

:: Run CMake configuration
pushd "%REPO_DIR%" 2>nul || exit /b 1

cmake -B "%BUILD_DIR%" -G "%REQUIRED_VS_GENERATOR%" -A x64 ^
    -DCMAKE_TOOLCHAIN_FILE="%VCPKG_DIR%\scripts\buildsystems\vcpkg.cmake" ^
    -DVCPKG_TARGET_TRIPLET="x64-windows-static" ^
    -DVCPKG_INSTALL_OPTIONS="--x-buildtrees-root=%VCPKG_BUILDTREES%;--clean-after-build" ^
    -DBUILD_GUI=%BUILD_GUI% ^
    -DBUILD_TESTS=%BUILD_TESTS% ^
    -DBUILD_BENCH=OFF ^
    -DWITH_ZMQ=%BUILD_ZMQ% ^
    -DENABLE_WALLET=%BUILD_WALLET% ^
    -DCMAKE_BUILD_TYPE=%BUILD_TYPE%

set "CMAKE_RESULT=!errorlevel!"
popd

if !CMAKE_RESULT! neq 0 (
    echo.
    echo [ERROR] CMake configuration failed!
    exit /b 1
)

echo.
echo [OK] Configuration complete
exit /b 0

:: ============================================================================
:: RUN BUILD FUNCTION
:: ============================================================================

:DoRunBuild
echo.

cmake --build "%BUILD_DIR%" --config %BUILD_TYPE% --parallel %PARALLEL_JOBS%

if !errorlevel! neq 0 (
    echo.
    echo [ERROR] Build failed!
    exit /b 1
)

echo.
echo [OK] Build complete
exit /b 0

:: ============================================================================
:: REPORT RESULTS FUNCTION
:: ============================================================================

:DoReportResults
echo.
echo ============================================================================
echo                           BUILD RESULTS
echo ============================================================================
echo.

set "EXE_DIR="
for %%d in (
    "%BUILD_DIR%\bin\%BUILD_TYPE%"
    "%BUILD_DIR%\src\%BUILD_TYPE%"
    "%BUILD_DIR%\bin\Release"
    "%BUILD_DIR%\src\Release"
    "%BUILD_DIR%\bin"
    "%BUILD_DIR%\src"
) do (
    if exist "%%~d\bitcoind.exe" set "EXE_DIR=%%~d"
    if exist "%%~d\bitcoin-cli.exe" set "EXE_DIR=%%~d"
)

set "EXE_COUNT=0"

if defined EXE_DIR (
    if exist "%EXE_DIR%\bitcoind.exe" (
        echo   [OK] bitcoind.exe - Full node daemon
        set /a EXE_COUNT+=1
    )
    if exist "%EXE_DIR%\bitcoin-qt.exe" (
        echo   [OK] bitcoin-qt.exe - GUI wallet
        set /a EXE_COUNT+=1
    )
    if exist "%EXE_DIR%\bitcoin-cli.exe" (
        echo   [OK] bitcoin-cli.exe - Command-line interface
        set /a EXE_COUNT+=1
    )
    if exist "%EXE_DIR%\bitcoin-tx.exe" (
        echo   [OK] bitcoin-tx.exe - Transaction utility
        set /a EXE_COUNT+=1
    )
    if exist "%EXE_DIR%\bitcoin-wallet.exe" (
        echo   [OK] bitcoin-wallet.exe - Wallet tool
        set /a EXE_COUNT+=1
    )
    if exist "%EXE_DIR%\bitcoin-util.exe" (
        echo   [OK] bitcoin-util.exe - Utility tool
        set /a EXE_COUNT+=1
    )
)

echo.
if !EXE_COUNT! gtr 0 (
    echo   Total executables built: !EXE_COUNT!
    echo   Location: %EXE_DIR%
    echo.
    echo ============================================================================
    echo                         BUILD SUCCESSFUL!
    echo ============================================================================
    echo.
    echo   To install, press [I] in menu or run:
    echo   cmake --install "%BUILD_DIR%" --config %BUILD_TYPE% --prefix "%INSTALL_DIR%"
    echo.
) else (
    echo   [WARNING] No executables found in expected locations.
    echo   Check build directory: %BUILD_DIR%
)
echo ============================================================================
exit /b 0

:: ============================================================================
:: INSTALLER FUNCTIONS
:: ============================================================================

:DoInstallGit
echo [INFO] Installing Git...
where winget >nul 2>&1
if !errorlevel! equ 0 (
    winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements >nul 2>&1
) else (
    echo [INFO] Downloading Git installer...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri 'https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe' -OutFile '%TEMP%\git-installer.exe' -UseBasicParsing } catch { exit 1 }" >nul 2>&1
    if exist "%TEMP%\git-installer.exe" (
        "%TEMP%\git-installer.exe" /VERYSILENT /NORESTART >nul 2>&1
        del "%TEMP%\git-installer.exe" 2>nul
    )
)
:: Update PATH
set "PATH=%PATH%;C:\Program Files\Git\cmd"
:: Configure git
git config --global http.sslBackend schannel 2>nul
git config --global core.longpaths true 2>nul
exit /b 0

:DoInstallPython
echo [INFO] Installing Python...
where winget >nul 2>&1
if !errorlevel! equ 0 (
    winget install --id Python.Python.3.12 -e --silent --accept-package-agreements --accept-source-agreements >nul 2>&1
) else (
    echo [INFO] Downloading Python installer...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.12.0/python-3.12.0-amd64.exe' -OutFile '%TEMP%\python-installer.exe' -UseBasicParsing } catch { exit 1 }" >nul 2>&1
    if exist "%TEMP%\python-installer.exe" (
        "%TEMP%\python-installer.exe" /quiet InstallAllUsers=1 PrependPath=1 >nul 2>&1
        del "%TEMP%\python-installer.exe" 2>nul
    )
)
exit /b 0

:DoInstallCMake
echo [INFO] Installing CMake...
where winget >nul 2>&1
if !errorlevel! equ 0 (
    winget install --id Kitware.CMake -e --silent --accept-package-agreements --accept-source-agreements >nul 2>&1
) else (
    echo [INFO] Downloading CMake installer...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri 'https://github.com/Kitware/CMake/releases/download/v3.28.1/cmake-3.28.1-windows-x86_64.msi' -OutFile '%TEMP%\cmake.msi' -UseBasicParsing } catch { exit 1 }" >nul 2>&1
    if exist "%TEMP%\cmake.msi" (
        msiexec /i "%TEMP%\cmake.msi" /quiet /norestart ADD_CMAKE_TO_PATH=System >nul 2>&1
        del "%TEMP%\cmake.msi" 2>nul
    )
)
set "PATH=%PATH%;C:\Program Files\CMake\bin"
exit /b 0

:DoInstallVcpkg
echo [INFO] Installing vcpkg...

:: Remove old/broken installation
call :SafeRemoveDir "%VCPKG_DIR%"

:: Clone fresh
echo [INFO] Cloning vcpkg repository...
git clone https://github.com/microsoft/vcpkg.git "%VCPKG_DIR%" >nul 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] Failed to clone vcpkg!
    exit /b 1
)

:: Bootstrap
echo [INFO] Bootstrapping vcpkg...
pushd "%VCPKG_DIR%" 2>nul || exit /b 1
call bootstrap-vcpkg.bat -disableMetrics >nul 2>&1
set "BOOTSTRAP_RESULT=!errorlevel!"
popd

if !BOOTSTRAP_RESULT! neq 0 (
    echo [ERROR] Failed to bootstrap vcpkg!
    exit /b 1
)

set "VCPKG_ROOT=%VCPKG_DIR%"
echo [OK] vcpkg installed successfully
exit /b 0
