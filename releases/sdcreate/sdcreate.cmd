@echo off
rem --- 'sdcreate.cmd' v2.5 by KdL (2017.09.18)

if "%~1"=="" color 1f&title SD-Card preparing tool

:begin
if not exist "OS\MSXDOS2.SYS" (
    color f0&echo.&echo 'MSXDOS2.SYS' is missing!
    set TIMEOUT=1&goto quit_0
)
if not exist "OS\COMMAND2.COM" (
    color f0&echo.&echo 'COMMAND2.COM' is missing!
    set TIMEOUT=1&goto quit_0
)
call :title
wmic logicaldisk where drivetype=2 get deviceid, filesystem, volumename, size

rem --- Input parameters
:target
setlocal ENABLEDELAYEDEXPANSION
set TIMEOUT=1
set /p dest=Enter the target drive letter:
if "%dest%"=="" endlocal&goto begin
set dest=%dest:~0,1%:
call :uppercase dest

set label=MSXFAT16
set /p label=Enter a label name (optional):
set label=%label:~0,11%

rem --- Start of process
call :title
echo ### Ready to format the SD-Card "%label%" (%dest%)
echo.
echo WARNING: ALL EXISTING DATA OF THE TARGET DEVICE WILL BE DESTROYED^^!
echo Press any key to continue...
pause >nul 2>nul

set clean=%cd%\cleanscript.tmp
set dps=%cd%\dpscript.tmp
set partsize=4095

rem --- Create a partition if SD-Card is higher than 4GB
call :title
echo # Formatting...
echo.
echo >%clean% select volume=%dest%
echo >>%clean% clean
diskpart /s %clean% >nul 2>&1

waitfor /T %TIMEOUT% pause >nul 2>nul
del %clean% >nul 2>nul

echo >%dps% select volume=%dest%
echo >>%dps% create partition primary size=%partsize%
echo >>%dps% format fs=fat label="%label%" quick
diskpart /s %dps% >nul 2>&1
md "%dest%\System Volume Information" >nul 2>nul
if exist "%dest%\System Volume Information" goto is_higher

rem --- Create a partition if SD-Card is lower than 4GB
echo >%dps% select volume=%dest%
echo >>%dps% create partition primary
echo >>%dps% format fs=fat label="%label%" quick
diskpart /s %dps% >nul 2>&1

rem --- Finalizing
:is_higher
del %dps% >nul 2>nul

echo ## Copying BIOS ...
echo.
if exist SDBIOS\OCM-BIOS.DAT (
    waitfor /T %TIMEOUT% pause >nul 2>nul
    if exist "%dest%\System Volume Information" rd /S /Q "%dest%\System Volume Information" >nul 2>nul
    copy SDBIOS\OCM-BIOS.DAT %dest% >nul 2>nul
)

echo ### Copying system files ...
echo.
copy OS\MSXDOS2.SYS %dest% >nul 2>nul
copy OS\NEXTOR.SYS %dest% >nul 2>nul
copy OS\COMMAND2.COM %dest% >nul 2>nul

if not exist "%dest%\COMMAND2.COM" (
    call :title
    color 4f
    echo ### CRITICAL ERROR: THE TARGET DRIVE IS NOT FOUND^^!
    del OCM-BIOS.DAT >nul 2>nul
    del MSXDOS2.SYS >nul 2>nul
    del NEXTOR.SYS >nul 2>nul
    del COMMAND2.COM >nul 2>nul
    waitfor /T %TIMEOUT% pause >nul 2>nul
    goto quit_0
)

echo #### Copying OS ...
echo.
copy SYSTEM\*.* %dest% >nul 2>nul

md %dest%\DOS >nul 2>nul
md %dest%\DOSTOOLS >nul 2>nul
md %dest%\HELP >nul 2>nul
md %dest%\MM >nul 2>nul
md %dest%\SOFARUN >nul 2>nul
md %dest%\UTILS >nul 2>nul
copy SYSTEM\DOS\*.* %dest%\DOS >nul 2>nul
copy SYSTEM\DOSTOOLS\*.* %dest%\DOSTOOLS >nul 2>nul
copy SYSTEM\HELP\*.HLP %dest%\HELP >nul 2>nul
copy SYSTEM\MM\*.* %dest%\MM >nul 2>nul
copy SYSTEM\SOFARUN\*.* %dest%\SOFARUN >nul 2>nul
copy SYSTEM\UTILS\*.* %dest%\UTILS >nul 2>nul

echo ##### Copying Core ...
echo.
copy core\*.np1 %dest% >nul 2>nul

rem --- End of process
echo Done^^!
:quit_0
waitfor /T %TIMEOUT% pause >nul 2>nul
goto quit

:uppercase
set %~1=!%1:a=A!
set %~1=!%1:b=B!
set %~1=!%1:c=C!
set %~1=!%1:d=D!
set %~1=!%1:e=E!
set %~1=!%1:f=F!
set %~1=!%1:g=G!
set %~1=!%1:h=H!
set %~1=!%1:i=I!
set %~1=!%1:j=J!
set %~1=!%1:k=K!
set %~1=!%1:l=L!
set %~1=!%1:m=M!
set %~1=!%1:n=N!
set %~1=!%1:o=O!
set %~1=!%1:p=P!
set %~1=!%1:q=Q!
set %~1=!%1:r=R!
set %~1=!%1:s=S!
set %~1=!%1:t=T!
set %~1=!%1:u=U!
set %~1=!%1:v=V!
set %~1=!%1:w=W!
set %~1=!%1:x=X!
set %~1=!%1:y=Y!
set %~1=!%1:z=Z!
goto:eof

:title
cls
echo MSX-X SD Card creator
echo =====================
echo.
goto:eof

:quit
endlocal
