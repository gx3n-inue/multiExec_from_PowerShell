param( $cmdListFileName, $maxProcessCount, $startInterval, $checkInterval, $retryCount, $exitWait )

##---------------------------------------------------------------------------##
## Print Arguments.
##---------------------------------------------------------------------------##
function varsWrite([string]$cmdListFileName, [int]$maxProcessCount, [int]$startInterval, [int]$checkInterval, [int]$retryCount, [int]$exitWait)
{
    Write-Output "`$cmdListFileName = $cmdListFileName"
    Write-Output "`$maxProcessCount = $maxProcessCount"
    Write-Output "`$startInterval = $startInterval"
    Write-Output "`$checkInterval = $checkInterval"
    Write-Output "`$retryCount = $retryCount"
    Write-Output "`$exitWait = $exitWait"
} 

##---------------------------------------------------------------------------##
## Get start position of argument of execution command
##---------------------------------------------------------------------------##
function getArgsPostion([string]$cmdLine)
{
    $pos1 = $cmdLine.IndexOf("`"")
    if ($pos1 -ge 0) {
        $pos2 = $pos1 + $cmdLine.Substring($pos1 + 1).IndexOf("`"")
        $posSPC = $pos2 + $cmdLine.Substring($pos2).IndexOf(" ")
    }
    else {
        $posSPC = $pos2 + $cmdLine.IndexOf(" ")
    }
    
    if ($posSPC -gt 0) {
        return $posSPC
    }
    else {
        return -1
    }
}

##---------------------------------------------------------------------------##
## Function to wait until the number of processes falls below the upper limit.
##---------------------------------------------------------------------------##
function waitEnableExec([int]$maxProcessCount, [int]$checkInterval, [int]$retryCount, [array]$pid_list)
{
    $loopCount = 0

    while (1) {
        $pCount = 0

        for ($i = 0; $i -lt $pid_list.Length; $i++ ) {
            if ((IsExist_targetProcesses $pid_list[$i]) -gt 0) {
                $pCount++
            }
            else {
                $pid_list[$i] = 0
            }
        }

        if ($pCount -lt $maxProcessCount) {
            return
        }

        $loopCount++

        if ($loopCount -ge $retryCount) {
            Write-Host "Process Count is MAX!!"

            while($true)
            {
                Write-Host "Force Quit(Q) or Wait Continue(C)?" -NoNewline
                $keyInfo = [Console]::ReadKey($true)

                if($keyInfo.Key -eq "Q") {
                    exit
                }
                elseif($keyInfo.Key -eq "C") {
                    Write-Host
                    break
                }
            }

            $loopCount = 0
        }
        else {
            # 指定時間待機する
            Start-Sleep $checkInterval
        }
    }
}

function IsExist_targetProcesses([int]$target_pid)
{
    return @(Get-Process -Id $target_pid -ErrorAction 0).Count
}


##---------------------------------------------------------------------------##
## Main
##---------------------------------------------------------------------------##
if (-Not($cmdListFileName)){
    Write-Host "Usage : multiExec_from_PS.ps1 <cmdListFile> <maxProcessCount> <startInterval> <checkInterval> <retryCount> <exitWait>"
    exit
}

if (-Not($maxProcessCount)){
    $maxProcessCount = 4
}

if (-Not($startInterval)){
    $startInterval = 1
}

if (-Not($checkInterval)){
    $checkInterval = 4
}

if (-Not($retryCount)){
    $retryCount = 4
}

if (-Not($exitWait)){
    $exitWait = $FALSE
}
else {
    $exitWait = $TRUE
}

# Print Arguments.
varsWrite $cmdListFileName $maxProcessCount $checkInterval $retryCount $exitWait

$f = (Get-Content $cmdListFileName) -as [string[]]
#Write-Host `$f.Length : $f.Length

$lines = @(0..($f.Length - 1))
#Write-Host `$lines.Length : $lines.Length

$i = 0
foreach ($currentLine in $f) {
    if ($currentLine.Substring(0,2) -eq ".\"){
        $currentLine = $currentLine.Substring(2)
    }
    $lines[$i]=$currentLine

    $i++
}

$pid_list = @(0..($MaxProcessCount - 1))

for ($i = 0; $i -lt $lines.Length; ) {
    
    # Wait until the number of processes falls below the upper limit.
    waitEnableExec $maxProcessCount $checkInterval $retryCount $pid_list

    for ($p = 0; $p -lt $pid_list.Length; $p++) {
        Write-Host `[$i] : $lines[$i]
        
        if (-Not($i -lt $lines.Length)) {
            break
        }

        if (($lines[$i].substring(0,1) -ne "#") -And ($pid_list[$p] -eq 0)) {

            $posSPC = getArgsPostion $lines[$i]

            if ($posSPC -gt 0) {
                # Argument decomposition check
            #   Write-Host $lines[$i].Substring(0,$posSPC)
            #   Write-Host $lines[$i].Substring($posSPC + 1)

                # Command parallel execution.
                $proc = Start-Process -PassThru $lines[$i].Substring(0, $posSPC) -ArgumentList $lines[$i].Substring($posSPC + 1)
            }
            else {
                # Command parallel execution.
                $proc = Start-Process -PassThru $lines[$i]
            }

            if ($proc) {
                $pid_list[$p] = $proc.Id
            #   Write-Host "`$proc.Id = "$proc.Id

                if ($exitWait -eq $TRUE) {
                    $proc.WaitForExit()
                }
            }
        }

        Start-Sleep $startInterval
        $i++
    }
}

$CommandName = Split-Path -Leaf $PSCommandPath
Write-Host $CommandName is Done...
