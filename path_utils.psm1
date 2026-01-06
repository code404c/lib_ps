#/shared_ps/path_utils.psm1
Import-Module "$PSScriptRoot\constants.psm1"
Import-Module "$PSScriptRoot\log_utils.psm1" -Function Write-Log

$FILE_NAME = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)

function Assert-PathExists {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [ValidateSet('Any', 'File', 'Dir')]
        [string]$Type = 'Any'
    )
    
    $FUNC_NAME = $MyInvocation.MyCommand.Name
    
    # Check if path exists
    if (-not (Test-Path $Path)) {
        Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Path '$Path' does not exist!"
        return $false
    }
    
    # If specific type is required, validate it
    if ($Type -ne 'Any') {
        $item = Get-Item $Path -ErrorAction SilentlyContinue
        
        if ($Type -eq 'File' -and $item.PSIsContainer) {
            Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Path '$Path' exists but is a directory, not a file!"
            return $false
        }
        
        if ($Type -eq 'Dir' -and -not $item.PSIsContainer) {
            Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Path '$Path' exists but is a file, not a directory!"
            return $false
        }
    }
    
    return $true
}

function Test-PathAndCreate{
    param(
        [string]$TargetDir = $PATHS.REPO_ROOT_DIR,
        [ValidateSet("d", "f")]
        [string]$Type = "d"
    )
    $FUNC_NAME = $MyInvocation.MyCommand.Name
    if (-not (Test-Path $TargetDir)) {
        if ($Type -eq "d"){
            New-Item -Path $TargetDir -ItemType Directory -Force | Out-Null
            Write-Log $FILE_NAME $FUNC_NAME "DEBUG" "Create Dir '$TargetDir'"
        }else{
            New-Item -Path $TargetDir -ItemType File -Force | Out-Null
            Write-Log $FILE_NAME $FUNC_NAME "DEBUG" "Create File '$TargetDir'"
        }
    }
}

function Get-DirectoryTree {
    param(
        [string]$TargetDir = $PATHS.REPO_ROOT_DIR,
        [string]$OutputPath = $PATHS.DESKTOP,
        [string[]]$IgnorePatterns = @('node_modules', '.idea', '.git', 'dist', 'build', '.vscode', '.next', 'coverage', '__pycache__', '.github')
    )
    $FUNC_NAME = $MyInvocation.MyCommand.Name

    if (-not (Assert-PathExists $TargetDir)) {
        return $false
    }

    # Get the folder name from the path
    $folder_name = Split-Path $TargetDir -Leaf
    # Create output file path
    $output_file = Join-Path $OutputPath "$folder_name.txt"

    Write-Log $FILE_NAME $FUNC_NAME "INFO" "Generating tree structure for: $TargetDir"
    # Store current location
    $current_location = Get-Location

    try {
        # Change to target directory
        Set-Location $TargetDir
        # Generate tree structure and filter out unwanted folders
        $tree_output = tree /f | findstr /v /i "$($IgnorePatterns -join ' ')"
        # Create output content with header
        $content = "# $TargetDir`n$tree_output"

        # Save to file with UTF-8 encoding
        $content | Out-File -FilePath $output_file -Encoding UTF8

        Write-Log $FILE_NAME $FUNC_NAME "INFO" "Tree structure saved succeed, File location '$output_file'"
        return $true

    } catch {
        Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Generating tree structure: $_"
        return $false
    } finally {
        # Restore original location
        Set-Location $current_location
    }
}

Export-ModuleMember -Function Assert-PathExists, Test-PathAndCreate, Get-DirectoryTree
