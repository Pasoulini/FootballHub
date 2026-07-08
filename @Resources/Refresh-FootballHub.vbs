Option Explicit

Dim shell, fso, scriptDir, ps, scriptPath, args, mode, cmd

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
ps = shell.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"
scriptPath = scriptDir & "\Generate-FootballHub.ps1"

mode = ""
If WScript.Arguments.Count > 0 Then
    mode = LCase(WScript.Arguments(0))
End If

args = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " & Chr(34) & scriptPath & Chr(34) & " -RefreshRainmeter"
If mode = "auto" Then
    args = args & " -ThrottleSeconds 55"
End If

cmd = Chr(34) & ps & Chr(34) & " " & args
shell.Run cmd, 0, False
