$PINGATTEMPTS = 1
$NULL_STRING = ""
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

    while ($counter -lt $PINGATTEMPTS) {
        if ($NULL_STRING -eq $SERVER_ADDRESS) {
            Write-Host "User did not fill string. Defaulting to win2022serv.nijland.lan..."
            $SERVER_ADDRESS = "win2022serv.nijland.lan"
        }
        $ping_status = (Test-Connection $SERVER_ADDRESS -Count 1).StatusCode
        if ($ping_status -ne 0) {
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

$SERVER_ADDRESS = serverName
$DURATION_SECONDS = duration

function insertUserInput {
    Clear-Content Signaleringen.txt
    Add-Content Signaleringen.txt "Address: $SERVER_ADDRESS"
    Add-Content Signaleringen.txt "Duration: $DURATION_SECONDS seconds"
    Add-Content Signaleringen.txt "----"
    Add-Content Signaleringen.txt ""

    Write-Host "Target server: $SERVER_ADDRESS"
    Write-Host "Duration: $DURATION_SECONDS"
}

function mainLoop {
    $current_duration = 0
    
    while ($current_duration -lt $DURATION_SECONDS) {
        Start-Sleep 5

        Get-Process | Format-Table -HideTableHeaders Id | Out-File current-processes.txt
        $current_processes = Get-Content current-processes.txt
        foreach ($working_pid in $current_processes) {
            $working_pid = $working_pid.replace(' ', '')

            $current_whitelist = Get-Content Whitelist.txt
            foreach ($whitelist_pid in $current_whitelist) {
                if ($whitelist_pid -eq $working_pid) {
                    $in_whitelist = $true
                }
            }

            $current_blacklist = Get-Content Signaleringen.txt
            foreach ($blacklist_pid in $current_blacklist) {
                if ($blacklist_pid -eq $working_pid) {
                    $in_blacklist = $true
                }
            }
        
            if ($in_whitelist -ne $true -and $in_blacklist -ne $true) {
                $answer = Read-Host "PID $working_pid is not in whitelist or blacklist. Add to whitelist (y/n)?"
                if ($answer -eq "y") {
                    Add-Content Whitelist.txt "$working_pid"
                }
                else {
                    Add-Content Signaleringen.txt "$working_pid"
                }
            }

            $in_blacklist = $false
            $in_whitelist = $false
        }

        $current_duration += 5
    }
}

insertUserInput
mainLoop

Write-Host "done."