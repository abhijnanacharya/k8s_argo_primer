@echo off

REM Gradle wrapper batch script
REM Minimal stub for Windows systems

set DIR=%~dp0

if exist "%DIR%gradle\wrapper\gradle-wrapper.jar" (
  java -jar "%DIR%gradle\wrapper\gradle-wrapper.jar" %*
) else (
  echo gradle-wrapper.jar not found. Please regenerate the Gradle wrapper using 'gradle wrapper'.
  exit /b 1
)
