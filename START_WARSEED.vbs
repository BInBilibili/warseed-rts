Option Explicit

Dim shell, fileSystem, projectRoot, command
Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

projectRoot = fileSystem.GetParentFolderName(WScript.ScriptFullName)
command = "cmd.exe /d /c " & Quote(projectRoot & "\START_WARSEED.cmd")
shell.Run command, 0, False

Function Quote(value)
    Quote = Chr(34) & value & Chr(34)
End Function
