@echo off
:START 
echo       db      `7MM"""YMM `7MM"""Yp, 
echo      ;MM:       MM    `7   MM    Yb 
echo     ,V^MM.      MM   d     MM    dP 
echo    ,M  `MM      MM""MM     MM"""bg. 
echo    AbmmmqMA     MM   Y     MM    `Y 
echo   A'     VML    MM         MM    ,9 
echo .AMA.   .AMMA..JMML.     .JMMmmmd9  
echo.
echo.
                                                                                                                                                                
cd /d "%~dp0"
echo Search folders and subfolders for *.exe and *.dll
echo.
set /p path=Please enter the main path of the installation that you want to block:


if exist %path% (
goto PROG
) else (
goto ERROR
) 

:ERROR
cls
echo.
echo.
echo ######## ########  ########   #######  ########  
echo ##       ##     ## ##     ## ##     ## ##     ## 
echo ##       ##     ## ##     ## ##     ## ##     ## 
echo ######   ########  ########  ##     ## ########  
echo ##       ##   ##   ##   ##   ##     ## ##   ##   
echo ##       ##    ##  ##    ##  ##     ## ##    ##  
echo ######## ##     ## ##     ##  #######  ##     ## 
echo.
echo.
echo !!! Directory not found, please make sure this directory exists !!!
pause
cls
goto START


:PROG
dir /s /b "%path%\*.exe">progs.txt
dir /s /b "%path%\*.dll">dlls.txt
for %%f in (%path%) do set name=%%~nxf
echo %name%>name.txt
Start "" /I /max "%~dp0\PS.bat"
exit 


