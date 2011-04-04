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

wpeinit

ping 127.0.0.1 -n 5 > nul

@echo off
ipconfig /all > mymac.log
for /f "tokens=2 delims=:" %%a in ('find "Physical" mymac.log') do (
for /f "tokens=1" %%b in ('echo %%a') do (
@echo curl.exe -s -G http://__SERVERIP__/ba/winst?mac=%%b -o winstall.bat
curl.exe -s -G http://__SERVERIP__/ba/winst?mac=%%b -o winstall.bat
winstall.bat
GOTO :EXIT
)
)

:EXIT
del mymac.log
