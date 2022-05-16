@echo off
echo.
echo.
echo.
echo.
echo       db                    mm              `7MM"""YMM   db                                               `7MM  `7MM  `7MM"""Yp, `7MM                     `7MM      
echo      ;MM:                   MM                MM    `7                                                      MM    MM    MM    Yb   MM                       MM      
echo     ,V^MM.    `7MM  `7MM  mmMMmm   ,pW"Wq.    MM   d   `7MM  `7Mb,od8  .gP"Ya  `7M'    ,A    `MF' ,6"Yb.    MM    MM    MM    dP   MM   ,pW"Wq.   ,p6"bo    MM  ,MP'
echo    ,M  `MM      MM    MM    MM    6W'   `Wb   MM""MM     MM    MM' "' ,M'   Yb   VA   ,VAA   ,V  8)   MM    MM    MM    MM"""bg.   MM  6W'   `Wb 6M'  OO    MM ;Y   
echo    AbmmmqMA     MM    MM    MM    8M     M8   MM   Y     MM    MM     8M""""""    VA ,V  VA ,V    ,pm9MM    MM    MM    MM    `Y   MM  8M     M8 8M         MM;Mm   
echo   A'     VML    MM    MM    MM    YA.   ,A9   MM         MM    MM     YM.    ,     VVV    VVV    8M   MM    MM    MM    MM    ,9   MM  YA.   ,A9 YM.    ,   MM `Mb. 
echo .AMA.   .AMMA.  `Mbod"YML.  `Mbmo  `Ybmd9'  .JMML.     .JMML..JMML.    `Mbmmd'      W      W     `Moo9^Yo..JMML..JMML..JMMmmmd9  .JMML. `Ybmd9'   YMbmd'  .JMML. YA.
echo.
echo.
echo.
echo.
cd /d "%~dp0"
echo The program is now running. 
echo This may take a few seconds depending on how many files are found
PowerShell.exe -executionpolicy remotesigned -file autofirewallblock.ps1 "& '% ~ dpn0.ps1'"
echo.
echo.
for /f %%i in (name.txt) do @echo %%i was blocked successfully
echo.
set /p exe=<count_pgr.txt
set /p dll=<count_dll.txt

echo %exe% exe were blocked
echo %dll% dll were blocked

echo.
echo.
echo  ,,                   
echo *MM                   
echo  MM                   
echo  MM,dMMb.  `7M'   `MF'
echo  MM    `Mb   VA   ,V  
echo  MM     M8    VA ,V   
echo  MM.   ,M9     VVV    
echo  P^YbmdP'      ,V     
echo               ,V      
echo            OOb"      
echo.
echo                                              ,,                                                                 ,,  
echo       db                    mm             `7MM                                  .g8""8q.                     `7MM  
echo      ;MM:                   MM               MM                                .dP'    `YM.                     MM  
echo     ,V^MM.    `7MMpMMMb.  mmMMmm   .gP"Ya    MM   ,pW"Wq.  `7MMpdMAo.  .gP"Ya  dM'      `MM `7M'    ,A    `MF'  MM  
echo    ,M  `MM      MM    MM    MM    ,M'   Yb   MM  6W'   `Wb   MM   `Wb ,M'   Yb MM        MM   VA   ,VAA   ,V    MM  
echo    AbmmmqMA     MM    MM    MM    8M""""""   MM  8M     M8   MM    M8 8M"""""" MM.      ,MP    VA ,V  VA ,V     MM  
echo   A'     VML    MM    MM    MM    YM.    ,   MM  YA.   ,A9   MM   ,AP YM.    , `Mb.    ,dP'     VVV    VVV      MM  
echo .AMA.   .AMMA..JMML  JMML.  `Mbmo  `Mbmmd' .JMML. `Ybmd9'    MMbmmd'   `Mbmmd'   `"bmmd"'        W      W     .JMML.
echo                                                              MM                                                     
echo                                                            .JMML.                                                   
del %cd%\*.txt
pause
exit