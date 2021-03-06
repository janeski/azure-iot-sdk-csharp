@REM Copyright (c) Microsoft. All rights reserved.
@REM Licensed under the MIT license. See LICENSE file in the project root for full license information.

@setlocal EnableExtensions EnableDelayedExpansion
@echo off

set current-path=%~dp0
rem // remove trailing slash
set current-path=%current-path:~0,-1%

set build-root=%current-path%\..\..\..
rem // resolve to fully qualified path
for %%i in ("%build-root%") do set build-root=%%~fi

rem ensure nuget.exe exists
where /q nuget.exe
if not !errorlevel! == 0 (
@Echo Azure IoT SDK needs to download nuget.exe from https://dist.nuget.org/win-x86-commandline/latest/nuget.exe 
@Echo https://www.nuget.org 
choice /C yn /M "Do you want to download and run nuget.exe"
if not !errorlevel!==1 goto :eof
rem if nuget.exe is not found, then ask user
Powershell.exe wget -outf nuget.exe https://dist.nuget.org/win-x86-commandline/latest/nuget.exe
	if not exist .\nuget.exe (
		echo nuget does not exist
		exit /b 1
	)
)

rem -----------------------------------------------------------------------------
rem -- parse script arguments
rem -----------------------------------------------------------------------------

rem // default build options
set build-clean=0
set build-config=Release
set build-platform="Any CPU"
set wip-provisioning=0

:args-loop
if "%1" equ "" goto args-done
if "%1" equ "-c" goto arg-build-clean
if "%1" equ "--clean" goto arg-build-clean
if "%1" equ "--config" goto arg-build-config
if "%1" equ "--platform" goto arg-build-platform
if "%1" equ "--wip-provisioning" goto arg-wip-provisioning
call :usage && exit /b 1

:arg-build-clean
set build-clean=1
goto args-continue

:arg-build-config
shift
if "%1" equ "" call :usage && exit /b 1
set build-config=%1
goto args-continue

:arg-build-platform
shift
if "%1" equ "" call :usage && exit /b 1
set build-platform=%1
goto args-continue

:arg-wip-provisioning
set wip-provisioning=1
goto args-continue

:args-continue
shift
goto args-loop

:args-done

rem -----------------------------------------------------------------------------
rem -- build csharp provisioning client
rem -----------------------------------------------------------------------------

call nuget restore -config "%current-path%\NuGet.Config" "%build-root%\provisioning\device\provisioning_deviceclient.sln"
if %build-clean%==1 (
    call :clean-a-solution "%build-root%\provisioning\device\provisioning_deviceclient.sln" %build-config% %build-platform%
    if not !errorlevel!==0 exit /b !errorlevel!
)
call :build-a-solution "%build-root%\provisioning\device\provisioning_deviceclient.sln" %build-config% %build-platform%
if not !errorlevel!==0 exit /b !errorlevel!

rem -----------------------------------------------------------------------------
rem -- done
rem -----------------------------------------------------------------------------

goto :eof


rem -----------------------------------------------------------------------------
rem -- subroutines
rem -----------------------------------------------------------------------------

:clean-a-solution
call :_run-msbuild "Clean" %1 %2 %3
echo !ERRORLEVEL!
goto :eof

:build-a-solution
call :_run-msbuild "Build" %1 %2 %3
goto :eof

:usage
echo build.cmd [options]
echo options:
echo  -c, --clean           delete artifacts from previous build before building
echo  --config ^<value^>      [Debug] build configuration (e.g. Debug, Release)
echo  --platform ^<value^>    [Win32] build platform (e.g. Win32, x64, ...)
goto :eof


rem -----------------------------------------------------------------------------
rem -- helper subroutines
rem -----------------------------------------------------------------------------

:_run-msbuild
rem // optionally override configuration|platform
setlocal EnableExtensions
set build-target=
if "%~1" neq "Build" set "build-target=/t:%~1"
if "%~3" neq "" set build-config=%~3
if "%~4" neq "" set build-platform=%~4

if %wip-provisioning%==1 (
    set extra-defines="WIP_PROVISIONING"
)

msbuild /m /t:Rebuild %build-target% "/p:Configuration=%build-config%;Platform=%build-platform%" /p:DefineConstants2=%extra-defines% %2
if not !ERRORLEVEL!==0 exit /b !ERRORLEVEL!
goto :eof
