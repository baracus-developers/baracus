wpeinit

ping 127.0.0.1 -n 5 > nul

@echo off
ipconfig /all > mymac.log
for /f "tokens=2 delims=:" %%a in ('find "Physical" mymac.log') do (
for /f "tokens=1" %%b in ('echo %%a') do (
@echo curl -G http://__SERVERIP__/ba/winst?mac=%%b -o winstall.bat
curl.exe -s -G http://__SERVERIP__/ba/winst?mac=%%b -o winstall.bat
winstall.bat
GOTO :EXIT
)
)

:EXIT
del mymac.log
