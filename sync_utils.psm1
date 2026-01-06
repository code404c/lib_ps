#/shared_ps/sync_utils.psm1
Import-Module "$PSScriptRoot\base.psm1" -Function Get-NowTime
Import-Module "$PSScriptRoot\constants.psm1"
Import-Module "$PSScriptRoot\path_utils.psm1" -Function Assert-PathExists
Import-Module "$PSScriptRoot\log_utils.psm1" -Function Write-Log

$FILE_NAME = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)

function Sync-Bin{
    Copy-Item -Path (Join-Path $PATHS.PS_BIN_DIR "*") -Destination $PATHS.BIN_DIR -Force
    Copy-Item -Path (Join-Path $PATHS.SHARED_BIN_DIR "*") -Destination $PATHS.BIN_DIR -Force
#    Copy-Item -Path (Join-Path $PATHS.SHARED_WIN_BIN_DIR "*") -Destination $PATHS.BIN_DIR -Force
}

function Push-GitRepo {
    param(
        [string]$TargetDir = $PATHS.REPO_ROOT_DIR,
        [Boolean]$SyncBin = $true,  
        [Boolean]$ForcePush = $false
    )
    $FUNC_NAME = $MyInvocation.MyCommand.Name

    if (-not (Assert-PathExists $TargetDir)) {
        return $false
    }

    try {
        # Add all changes
        git -C $TargetDir add .
        if ($LASTEXITCODE -ne 0) {
            Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Git add failed"
            return $false
        }

        # Check if there are changes to commit
        $status = git -C $TargetDir status --porcelain
        if (-not $status) {
            Write-Log $FILE_NAME $FUNC_NAME "INFO" "No changes to commit"
            return $true
        }

        # Commit changes
        $commitMsg = "$(Get-NowTime $false) $($SYSTEM.DEVICE_NAME) Auto commit"
        git -C $TargetDir commit -m $commitMsg
        if ($LASTEXITCODE -ne 0) {
            Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Git commit failed"
            return $false
        }

        # Check if there are commits to push
        $count = git -C $TargetDir rev-list --count origin/main..main
        if ($LASTEXITCODE -ne 0) {
            Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Git rev-list failed"
            return $false
        }

        if ($count -eq 0) {
            Write-Log $FILE_NAME $FUNC_NAME "INFO" "No commits to push"
            return $true
        }

        # Push commits
        if ($ForcePush) {
            Write-Log $FILE_NAME $FUNC_NAME "WARNING" "Force pushing $count commit(s)"
            git -C $TargetDir push -f origin main
        } else {
            git -C $TargetDir push origin main
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Git push failed"
            return $false
        }

        # Sync binary files if needed
        if ($SyncBin) {
            Sync-Bin
        }

        Write-Log $FILE_NAME $FUNC_NAME "INFO" "Git push completed successfully, pushed $count commit(s)"
        return $true

    } catch {
        Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Error during git push: $_"
        return $false
    }
}

function Reset-GitRepo {
    param(
        [string]$TargetDir = $PATHS.REPO_ROOT_DIR,
        [Boolean]$SyncBin = $true
    )
    $FUNC_NAME = $MyInvocation.MyCommand.Name

    if (-not (Assert-PathExists $TargetDir)) {
        return $false
    }

    try {
        # Use git -C to avoid directory switching
        git -C $TargetDir fetch
        if ($LASTEXITCODE -ne 0) {
            Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Git fetch failed (network?)"
            return $false
        }

        $count = git -C $TargetDir rev-list --count main..origin/main
        if ($LASTEXITCODE -ne 0) {
            Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Git rev-list failed"
            return $false
        }

        if ($count -gt 0) {
            git -C $TargetDir reset --hard origin/main
            if ($LASTEXITCODE -ne 0) {
                Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Git reset --hard failed"
                return $false
            }
            
            if ($SyncBin) {
                Sync-Bin
            }
            
            Write-Log $FILE_NAME $FUNC_NAME "INFO" "Git reset completed successfully, synced $count commits"
            return $true
        } else {
            Write-Log $FILE_NAME $FUNC_NAME "INFO" "Local is already up to date"
            return $true
        }
    } catch {
        Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Error during git reset: $_"
        return $false
    }
}

Export-ModuleMember -Function Push-GitRepo,Reset-GitRepo,Sync-Bin