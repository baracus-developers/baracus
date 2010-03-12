wpeinit

ping 127.0.0.1 -n 5 > nul

@echo off
ipconfig /all > mymac.log
for /f "tokens=2 delims=:" %%a in ('find "Physical" mymac.log') do (
for /f "tokens=1" %%b in ('echo %%a') do (
@echo curl -G http://151.155.230.38/ba/winst?mac=%%b -o winstall.bat
curl.exe -s -G http://151.155.230.38/ba/winst?mac=%%b -o winstall.bat
winstall.bat
GOTO :EXIT
)
)

:EXIT
del mymac.log
