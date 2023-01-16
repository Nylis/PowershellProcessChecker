# Please check if you are using a recent powershell version before performing this script. ping tests might fail otherwise.
# Make sure this script and included files reside in the same directory

# Initial setup for windows users (if using remote access):
# Install-Module WinRM
# Start-Service WinRM
# Set-Item WSMan:\localhost\Client\TrustedHosts -Value *

# Default values
$PINGATTEMPTS = 1
$NULL_STRING = ""
$INTERVAL = 5 # seconds
$WHITELIST_FILE = "Whitelist.txt"
$CURRENT_PROCESSES_FILE = "current-processes.txt"
$BLACKLIST_FILE = "Signaleringen.txt"

$counter = 0

# Function that exits program immediately.
function endScript
{
    Write-Host "Aborting..."
    exit
}

function serverName
{
    # Ask the user to insert ip address or domain name.
    Write-Host "Insert the following data."
    $SERVER_ADDRESS = Read-Host "Server address (ip or domain name)"

    if ($NULL_STRING -eq $SERVER_ADDRESS) {
        $SERVER_ADDRESS = "win2022serv.nijland.lan" # default address
        Write-Host "User did not fill string. Defaulting to $SERVER_ADDRESS..."
    }

    # Test network connection based on total ping attempts. Quit if ping fails.
    while ($counter -lt $PINGATTEMPTS) {
        Write-Host "Performing ping test $counter..."
        $ping_status = (Test-Connection $SERVER_ADDRESS -Count 1).Status
        if ($ping_status -ne "Success") {
            Write-Host "Ping to system failed. Check your network connection and try again."
            endScript
        }

        $counter += 1
    }
    $counter = 0

    return $SERVER_ADDRESS
}

function remoteLogin {
    # Ask user for username before attempting login.
    $USERNAME = Read-Host "Username [Domain\]<Username>"
    if ($NULL_STRING -eq $USERNAME) {
        $USERNAME = "Administrator" # Default username
        Write-Host "User did not insert username, defaulting to $USERNAME..."
    }
    
    # Attempt login, quit when failed.
    try {
        Write-Host "Prompting login..."
        $S = New-PSSession -ComputerName $SERVER_ADDRESS -Credential $USERNAME
    }

    catch {
        Write-Host "Login failed."
        endScript
    }

    return $S
}

function duration {
    # Ask user for total duration
    [uint16]$DURATION = Read-Host "Duration (in minutes)"
    if ($NULL_STRING -eq $DURATION) {
        $DURATION = 1 # Default minute(s)
        Write-Host "User did not fill string. Defaulting to 1 minute..."
    }

    $DURATION_SECONDS = $DURATION * 60
    return $DURATION_SECONDS
}

function instantWhitelist {
    # Ask user to whitelist all PIDs during first cycle
    $instant_whitelist = Read-Host "Whitelist all PIDs during first cycle (y/n)?"
    if ($instant_whitelist -eq "y") {
        $instant_whitelist = $true
    }
    else {
        $instant_whitelist = $false
    }

    return $instant_whitelist
}

# Basic top formatting for $BLACKLIST_FILE
function insertUserInput {
    Clear-Content $BLACKLIST_FILE
    Add-Content $BLACKLIST_FILE "Address: $SERVER_ADDRESS"
    Add-Content $BLACKLIST_FILE "Duration: $DURATION_SECONDS seconds"
    Add-Content $BLACKLIST_FILE "----"
    Add-Content $BLACKLIST_FILE ""

    Write-Host "Target server: $SERVER_ADDRESS"
    Write-Host "Duration: $DURATION_SECONDS"
}

function mainLoop {
    $current_duration = 0
    $cycle = 0

    # Main loop, stop if duration exceeds user-inserted or default duration.
    while ($current_duration -lt $DURATION_SECONDS) {
        # Print interval timer
        $timer = $INTERVAL
        while ($counter -lt $INTERVAL) {
            Write-Host "Performing next cycle in $timer seconds..." 
            $dots += ". " 
            $counter += 1
            $timer -= 1
            Start-Sleep 1
        }
        $counter = 0
        
        # Get all processes from remote or local system and insert into $CURRENT_PROCESSES_FILE
        if ($remoteCheck -eq $true) {
            $remoteProcesses = Invoke-Command -Session $S {
                Get-Process | Format-Table -HideTableHeaders Id
            }
            $remoteProcesses | Out-File $CURRENT_PROCESSES_FILE
        }
        else {
            Get-Process | Format-Table -HideTableHeaders Id | Out-File $CURRENT_PROCESSES_FILE
        }

        # Read every PID from output
        $current_processes = Get-Content $CURRENT_PROCESSES_FILE
        foreach ($working_pid in $current_processes) {
            $working_pid = $working_pid.replace(' ', '')
            
            # Compare current PID with every whitelisted PID
            $current_whitelist = Get-Content $WHITELIST_FILE
            foreach ($whitelist_pid in $current_whitelist) {
                if ($whitelist_pid -eq $working_pid) {
                    $in_whitelist = $true
                }
            }
            
            # Compare current PID with every blacklisted PID
            $current_blacklist = Get-Content $BLACKLIST_FILE
            foreach ($blacklist_pid in $current_blacklist) {
                if ($blacklist_pid -eq $working_pid) {
                    $in_blacklist = $true
                }
            }
            
            # Check if PID is present in white- or blacklist. If not, ask to insert into white- or blacklist.
            # Skip this block regardless if instant_whitelist is set to $true
            if ($in_whitelist -ne $true -and $in_blacklist -ne $true -and $instant_whitelist -ne $true) {
                $answer = Read-Host "PID $working_pid is not in whitelist or blacklist. Add to whitelist (y/n)?"
                if ($answer -eq "y") {
                    Write-Host "Added $working_pid to $WHITELIST_FILE"
                    Add-Content $WHITELIST_FILE "$working_pid"
                }
                else {
                    Write-Host "Added $working_pid to $BLACKLIST_FILE"
                    Add-Content $BLACKLIST_FILE "$working_pid"
                }
            }
            
            # Automatically add PID to whitelist if $instant_whitelist is set to $true
            if ($instant_whitelist -eq $true) {
                Write-Host "Added $working_pid to $WHITELIST_FILE"
                Add-Content $WHITELIST_FILE "$working_pid"
            }

            # Reset values at end of PID analysis
            $in_blacklist = $false
            $in_whitelist = $false
        }

        #Add to interval, reset $instant_whitelist and increment cycle ID
        $current_duration += $INTERVAL
        $instant_whitelist = $false
        $cycle += 1
        Write-Host "Cycle $cycle completed."
    }
}

function wrapUp {
    Write-Host "Process check finalized."

    # Ask user if whitelist needst to be emptied
    $answer = Read-Host "Empty $WHITELIST_FILE (y/n)?"
    if ($answer -eq "y") {
        Write-Host "$WHITELIST_FILE cleared."
        Clear-Content $WHITELIST_FILE
    }

    # Ask user if $BLACKLIST_FILE needs to be printed to console
    $answer = Read-Host "Print $BLACKLIST_FILE to screen (y/n)?"
    if ($answer -eq "y") {
        $contents = Get-Content $BLACKLIST_FILE
        foreach ($blacklist_pid in $contents) {
            Write-Host "$blacklist_pid"
        }
    }
}


$DURATION_SECONDS = duration

# Ask user for a remote or local process check, skip certain steps if local is chosen.
$answer = Read-Host "Perform a remote (1) or local (2) check?"
if ($answer -eq "1") {
    $remoteCheck = $true
    $SERVER_ADDRESS = serverName
    $S = remoteLogin
}
else {
    $remoteCheck = $false
    $SERVER_ADDRESS = hostname
}

$instant_whitelist = instantWhitelist

insertUserInput
mainLoop
wrapUp

# Disconnect from PSSession and finalize script
Remove-PSSession -Session $S
Write-Host "Done."