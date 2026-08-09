@echo off
setlocal

set PARAMS=%*

:: E:\dev\jai\jai-beta-2-026\jai\bin\jai.exe .\build.jai - %PARAMS%
jai.exe .\build.jai - %PARAMS%

if %errorlevel% neq 0 (
	echo Compilation failed
	exit /b %errorlevel%
)

.\ez.exe

endlocal