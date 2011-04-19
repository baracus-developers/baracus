REM @echo off

REM #########################################################################
REM 
REM Baracus build and boot management framework
REM 
REM Copyright (C) 2010 Novell, Inc, 404 Wyman Street, Waltham, MA 02451, USA.
REM 
REM This program is free software; you can redistribute it and/or
REM modify it under the terms of the Artistic License 2.0, as published
REM by the Perl Foundation, or the GNU General Public License 2.0
REM as published by the Free Software Foundation; your choice.
REM 
REM This program is distributed in the hope that it will be useful,
REM but WITHOUT ANY WARRANTY; without even the implied warranty of
REM MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  Both the Artistic
REM Licesnse and the GPL License referenced have clauses with more details.
REM 
REM You should have received a copy of the licenses mentioned
REM along with this program; if not, write to:
REM 
REM FSF, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110, USA.
REM The Perl Foundation, 6832 Mulderstraat, Grand Ledge, MI 48837, USA.
REM 
REM #########################################################################

cls
	 
REM __Variables__
REM usage: bawinstall.bat <DRIVE LETTER>
echo Setting Paths...
set NETDRIVE=%1
set WAIKPath=%ProgramFiles%\Windows AIK
set WAIKTools=%WAIKPath%\Tools
set ARCH=%PROCESSOR_ARCHITECTURE%
set PEPath=C:\baracus\winpe_%ARCH%
set TFTPPath=%NETDRIVE%:\import\%ARCH%
set BCDStore=c:\BCD
	 
REM __Copy required files__
echo Preparing Files...
cd "%WAIKPath%\Tools\PETools"
call "%WAIKTools%\PETools\copype" %ARCH% %PEPath%
"%WAIKTools%\%ARCH%\imagex" /mountrw %PEPath%\winpe.wim 1 %PEPath%\mount

copy "%PEPath%\mount\windows\Boot\PXE\bootmgr.exe" "%TFTPPath%\bootmgr.exe" > NUL
copy "%PEPath%\mount\Windows\Boot\PXE\pxeboot.n12" "%TFTPPath%\startrom.0" > NUL
copy "%WAIKPath%\Tools\PETools\%ARCH%\boot\boot.sdi" "%TFTPPath%\boot.sdi" > NUL
copy "%PEPath%\winpe.wim" "%TFTPPath%\boot.wim" > NUL

REM __Create BCD__
echo Creating BCD...
cd %PEPath%\mount\Windows\System32
bcdedit -createstore %BCDStore%
bcdedit -store %BCDStore% -create {ramdiskoptions} /d "Ramdisk options"
bcdedit -store %BCDStore% -set {ramdiskoptions} ramdisksdidevice  Boot
bcdedit -store %BCDStore% -set {ramdiskoptions} ramdisksdipath  \Boot\boot.sdi

for /f "Tokens=3" %%i in ('bcdedit /store %BCDStore% /create /d "Windows Install Image" /application osloader') do set GUID=%%i

bcdedit -store %BCDStore% -set %GUID% systemroot \Windows
bcdedit -store %BCDStore% -set %GUID% detecthal Yes
bcdedit -store %BCDStore% -set %GUID% winpe Yes
bcdedit -store %BCDStore% -set %GUID% osdevice ramdisk=[boot]\Boot\boot.wim,{ramdiskoptions}
bcdedit -store %BCDStore% -set %GUID% device ramdisk=[boot]\Boot\boot.wim,{ramdiskoptions}

bcdedit -store %BCDStore% -create {bootmgr} /d "Windows Boot Manager"
bcdedit -store %BCDStore% -set {bootmgr} timeout 30
bcdedit -store %BCDStore% -set {bootmgr} displayorder %GUID%

cd c:\
"%WAIKTools%\%ARCH%\imagex" /unmount %PEPATH%\mount

copy c:\BCD "%TFTPPath%\BCD" > NUL

REM __Prep boot.wim for Baracus__
echo Building winpe boot.wim...
"%WAIKTools%\%ARCH%\imagex" /mountrw %TFTPPath%\boot.wim 1 %PEPath%\mount
 
copy %NETDRIVE%:\install\%ARCH%\curl.exe "%PEPath%\mount\Windows\System32\curl.exe"
copy /Y %NETDRIVE%:\install\startnet.cmd "%PEPath%\mount\Windows\System32\startnet.cmd"

"%WAIKTools%\%ARCH%\imagex" /unmount %PEPath%\mount /commit

echo Setup complete...
echo Please run "basource add --distro <ostype>" on your Baracus server...
