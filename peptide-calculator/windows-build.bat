@echo off
echo Building HPLC Peptide Calculator for Windows...
echo Built by Peter Kubiniok
echo.

REM Install dependencies
echo Installing dependencies...
call npm install

REM Build the React app
echo Building React app...
call npm run build

REM Create a simple Windows package
echo Creating Windows package...
mkdir dist\windows-package 2>nul
xcopy build\* dist\windows-package\ /E /I /Y
copy public\electron.js dist\windows-package\
copy package.json dist\windows-package\

echo.
echo Windows package created in dist\windows-package\
echo To run: cd dist\windows-package && npm install && npm run electron
echo.
pause

