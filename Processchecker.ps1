# Please check if you are using a recent powershell version before performing this script

$PINGATTEMPTS = 1
$NULL_STRING = ""
$INTERVAL = 5 # seconds
$WHITELIST_FILE = "Whitelist.txt"
$CURRENT_PROCESSES_FILE = "current-processes.txt"
$BLACKLIST_FILE = "Signaleringen.txt"
$counter = 0

function endScript
{
    Write-Host "Aborting..."
    exit
}

function serverName
{
    Write-Host "Insert the following data."
    $SERVER_ADDRESS = Read-Host "Servername"

    if ($NULL_STRING -eq $SERVER_ADDRESS) {
        $SERVER_ADDRESS = "win2022serv.nijland.lan"
        Write-Host "User did not fill string. Defaulting to $SERVER_ADDRESS..."
    }

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

function duration {
    $DURATION = Read-Host "Duration (in minutes)"
    if ($NULL_STRING -eq $DURATION) {
        Write-Host "User did not fill string. Defaulting to 1 minute..."
        $DURATION = 1
        $DURATION_SECONDS = $DURATION * 60
    }

    return $DURATION_SECONDS
}

function instantWhitelist {
    $instant_whitelist = Read-Host "Whitelist all PIDs during first cycle (y/n)?"
    if ($instant_whitelist -eq "y") {
        $instant_whitelist = $true
    }
    else {
        $instant_whitelist = $false
    }

    return $instant_whitelist
}

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

    while ($current_duration -lt $DURATION_SECONDS) {
        $timer = $INTERVAL
        while ($counter -lt $INTERVAL) {
            Write-Host "Performing next cycle in $timer seconds..." 
            $dots += ". " 
            $counter += 1
            $timer -= 1
            Start-Sleep 1
        }
        $counter = 0

        Get-Process | Format-Table -HideTableHeaders Id | Out-File $CURRENT_PROCESSES_FILE
        $current_processes = Get-Content $CURRENT_PROCESSES_FILE
        foreach ($working_pid in $current_processes) {
            $working_pid = $working_pid.replace(' ', '')

            $current_whitelist = Get-Content $WHITELIST_FILE
            foreach ($whitelist_pid in $current_whitelist) {
                if ($whitelist_pid -eq $working_pid) {
                    $in_whitelist = $true
                }
            }

            $current_blacklist = Get-Content $BLACKLIST_FILE
            foreach ($blacklist_pid in $current_blacklist) {
                if ($blacklist_pid -eq $working_pid) {
                    $in_blacklist = $true
                }
            }
        
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

            if ($instant_whitelist -eq $true) {
                Write-Host "Added $working_pid to $WHITELIST_FILE"
                Add-Content $WHITELIST_FILE "$working_pid"
            }

            $in_blacklist = $false
            $in_whitelist = $false
        }

        $current_duration += $INTERVAL
        $instant_whitelist = $false
        $cycle += 1
        Write-Host "Cycle $cycle completed."
    }
}

$SERVER_ADDRESS = serverName
$DURATION_SECONDS = duration
$instant_whitelist = instantWhitelist

insertUserInput
mainLoop

Write-Host "done."