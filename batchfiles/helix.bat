@echo off
:parse
IF "%1"=="" GOTO default
set BASE=%1
GOTO submit

:default
set BASE=%PWD%

:submit
FOR /F %%i IN ('wslpath -u %BASE%') DO set TARGET=%%i
@call wsl.exe --shell-type login /usr/bin/hx %TARGET%
