@echo off
rem AutoFirewallBlock launcher - starts autofirewallblock.ps1 (asks for admin rights itself).
rem Parameters are passed through, e.g.: autofirewallblock.bat -Path "C:\Games\SomeGame"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0autofirewallblock.ps1" %*
