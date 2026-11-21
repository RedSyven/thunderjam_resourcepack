@echo off
setlocal
 
:: Drag and drop your image onto this .bat file, or edit the path below
if "%~1"=="" (
    set "INPUT=image.png"
) else (
    set "INPUT=%~1"
)
 
echo Splitting "%INPUT%" into 1080x1080 tiles...
magick "%INPUT%" -crop 1080x1080 +repage -scene 1 "split-%%d.png"
 
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Make sure ImageMagick is installed.
    echo Download it at https://imagemagick.org/script/download.php
    pause
    exit /b 1
)
 
echo Done!
pause