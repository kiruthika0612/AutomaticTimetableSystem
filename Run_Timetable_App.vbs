Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

projectPath = fso.GetParentFolderName(WScript.ScriptFullName)
batPath = projectPath & "\Run_Timetable_App.bat"

shell.Run Chr(34) & batPath & Chr(34), 0, False
