#/shared_ps/service_utils.psm1
Import-Module "$PSScriptRoot\constants.psm1"
Import-Module "$PSScriptRoot\log_utils.psm1" -Function Write-Log
Import-Module "$PSScriptRoot\os_utils.psm1" -Function Get-ProcessSafe
Import-Module "$PSScriptRoot\path_utils.psm1" -Function Assert-PathExists

$FILE_NAME = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)

function Start-Frpc{
    param(
        [Boolean]$Restart = $false
    )
    $FUNC_NAME = $MyInvocation.MyCommand.Name

    $frpcProcess = Get-ProcessSafe -process_name "frpc"
    if ($frpcProcess) {
        if ($Restart) {
            Write-Log $FILE_NAME $FUNC_NAME "DEBUG" "Stopping existing frpc process (PID: $($frpcProcess.Id))"
            Stop-Process -Id $frpcProcess.Id -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        } else {
            Write-Log $FILE_NAME $FUNC_NAME "WARNING" "Frpc is already running, PID: $($frpcProcess.Id)"
            return $true
        }
    }

    Write-Log $FILE_NAME $FUNC_NAME "INFO" "Starting frpc service" -ForegroundColor Yellow

    $frpcBin = "$($PATHS.CODE)\frpc.exe"
    $frpcConfigFile = "$env:ProgramData\frpc\frpc.toml"
    if(-not (Assert-PathExists $frpcBin)) {return $false}
    if(-not (Assert-PathExists $frpcConfigFile)) {return $false}


    Start-Process "$frpcBin" -ArgumentList @("-c", "$frpcConfigFile") -WorkingDirectory "$($PATHS.CODE)" -WindowStyle Hidden
    Write-Log $FILE_NAME $FUNC_NAME "DEBUG" "Start frpc: $frpcBin -c $frpcConfigFile"
    $frpcProcess = Get-ProcessSafe -process_name "frpc"
    if (-not $frpcProcess){
        Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Start frpc failure"
        return $false
    }
    return $true

}

function Start-Syncthing{
    param(
        [Boolean]$Restart = $false
    )
    $FUNC_NAME = $MyInvocation.MyCommand.Name

    $syncthingProcess = Get-ProcessSafe -process_name "syncthing"
    if ($syncthingProcess) {
        if ($Restart) {
            Write-Log $FILE_NAME $FUNC_NAME "DEBUG" "Stopping existing webdav process (PID: $($syncthingProcess.Id))"
            Stop-Process -Id $syncthingProcess.Id -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3
        } else {
            Write-Log $FILE_NAME $FUNC_NAME "WARNING" "Syncthing is already running, PID: $($syncthingProcess.Id)"
            return $true
        }
    }


    Write-Log $FILE_NAME $FUNC_NAME "INFO" "Starting syncthing service" -ForegroundColor Yellow
    $syncthingBin = "$($PATHS.CODE)\syncthing.exe"
    if(-not (Assert-PathExists $syncthingBin)) {return $false}



    Start-Process "$syncthingBin" -ArgumentList @("--no-console", "--no-browser") -WorkingDirectory "$($PATHS.CODE)" -WindowStyle Hidden

    Write-Log $FILE_NAME $FUNC_NAME "DEBUG" "Start Syncthing: $syncthingBin --no-console --no-browser"
    Start-Sleep -Seconds 4
    $syncthingProcess = Get-ProcessSafe -process_name "syncthing"
    if (-not $syncthingProcess){
        Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Start Syncthing failure"
        return $false
    }
    return $true
}

function Test-Tailscale{
    & tailscale status > $null 2>&1
    if($LASTEXITCODE -eq 0){
        return $true
    }
    else{
        return $false
    }
}

function Start-SSH {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$HostName,
        [string]$IdentityFile,
        [int]$Port = 22,
        [string]$User = "root",
        [int]$Timeout = 10
    )
    $FUNC_NAME = $MyInvocation.MyCommand.Name
    
    # Build SSH command with required parameters
    $sshCommand = "ssh $User@$HostName -p $Port -o ConnectTimeout=$Timeout"
    
    # Add identity file parameter only if provided
    if (-not [string]::IsNullOrEmpty($IdentityFile)) {
        $sshCommand += " -i `"$IdentityFile`""
    }
    
    # Log the command
    Write-Log $FILE_NAME $FUNC_NAME "DEBUG" "$sshCommand"
    
    # Execute SSH command
    Invoke-Expression $sshCommand
}

function Start-Tailscale{
    param(
        [Boolean]$Restart = $false
    )
    $FUNC_NAME = $MyInvocation.MyCommand.Name

    if(Test-Tailscale){
        Write-Log $FILE_NAME $FUNC_NAME "WARNING" "Tailscale is already up"
        if(-not $Restart){
            return $true
        }else{
            $null = & tailscale down > $null 2>&1
            Start-Sleep -Seconds 3
        }
    }
    $out = & tailscale up 2>&1
    Start-Sleep -Seconds 3
    if($LASTEXITCODE -eq 0){
        Write-Log $FILE_NAME $FUNC_NAME "INFO" "Tailscale is up"
        return $true
    }else{
        Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Tailscale up: $out"
        return $false
    }
    
}

function Start-WebDav{
    param(
        [Boolean]$Restart = $false
    )
    $FUNC_NAME = $MyInvocation.MyCommand.Name

    $webdavProcess = Get-ProcessSafe -process_name "webdav"
    if ($webdavProcess) {
        if ($Restart) {
            Write-Log $FILE_NAME $FUNC_NAME "DEBUG" "Stopping existing webdav process (PID: $($webdavProcess.Id))"
            Stop-Process -Id $webdavProcess.Id -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3
        } else {
            Write-Log $FILE_NAME $FUNC_NAME "WARNING" "WebDav is already running, PID: $($webdavProcess.Id)"
            return $true
        }
    }

    Write-Log $FILE_NAME $FUNC_NAME "INFO" "Starting WebDav service" -ForegroundColor Yellow

    $webdavBin = "$($PATHS.CODE)\webdav.exe"
    $webdavConfigFile = "$env:ProgramData\webdav\webdav.json"
    if(-not (Assert-PathExists $webdavBin)) {return $false}
    if(-not (Assert-PathExists $webdavConfigFile)) {return $false}


    Start-Process "$webdavBin" -ArgumentList @("--config", "$webdavConfigFile") -WorkingDirectory "$($PATHS.CODE)" -WindowStyle Hidden

    Write-Log $FILE_NAME $FUNC_NAME "DEBUG" "Start WebDav: $webdavBin --config $webdavConfigFile"
    Start-Sleep -Seconds 4
    $webdavProcess = Get-ProcessSafe -process_name "webdav"
    if (-not $webdavProcess){
        Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Start WebDav failure"
        return $false
    }
    return $true
}

Export-ModuleMember -Function *
