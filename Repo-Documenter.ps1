param(
    [Parameter(Mandatory=$true)]
    [string]$RepoPath,
    [string]$OutputFile = ""
)

# Ensure RepoPath is a full path
$RepoPath = Resolve-Path $RepoPath

# Extract project name from RepoPath
$projectName = Split-Path -Leaf $RepoPath

# Set OutputFile name based on project name if not provided
if ([string]::IsNullOrEmpty($OutputFile)) {
    $OutputFile = "$projectName.md"
}

# Define backticks as a string variable with six backticks to escape aggregated markdown code blocks
$backticks = '``````'

function Get-ConfigurationPatterns {
    param([string]$RepoPath)
    $configPath = Join-Path $RepoPath "repo_documenter.config"
    if (Test-Path $configPath) {
        $patterns = Get-Content $configPath | Where-Object { $_ -notmatch '^\s*#' -and $_ -notmatch '^\s*$' }
        Write-Host "Inclusion patterns: $($patterns -join ', ')"
        return $patterns
    }
    Write-Host "No repo_documenter.config file found at $configPath"
    return @()
}

function Test-ConfigurationPath {
    param(
        [string]$Path,
        [array]$configurationPatterns
    )
    $relativePath = $Path.Substring($RepoPath.Length).TrimStart('\', '/').Replace('\', '/')
    foreach ($pattern in $configurationPatterns) {
        if ($pattern.EndsWith('*')) {
            $dirPattern = $pattern.TrimEnd('*').TrimEnd('/')
            if ($relativePath.StartsWith($dirPattern, [StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        } elseif ($relativePath -like $pattern) {
            return $true
        }
    }
    return $false
}

function Get-TreeView {
    param(
        [string]$Path,
        [string]$Prefix = "",
        [array]$configurationPatterns,
        [bool]$IsLast = $false,
        [ref]$TotalDirCount,
        [ref]$TotalFileCount
    )
    $items = Get-ChildItem -Path $Path -Force | Sort-Object { $_.PSIsContainer }, { $_.Name }
    $treeView = @()
    $localDirCount = 0
    $localFileCount = 0

    $configurationItems = @()
    foreach ($item in $items) {
        $relativePath = $item.FullName.Substring($RepoPath.Length).TrimStart('\', '/').Replace('\', '/')
        if (Test-ConfigurationPath -Path $item.FullName -configurationPatterns $configurationPatterns) {
            $configurationItems += $item
        } elseif ($item.PSIsContainer -and ($configurationPatterns | Where-Object { $_ -like "$relativePath*" })) {
            $configurationItems += $item
        }
    }

    for ($i = 0; $i -lt $configurationItems.Count; $i++) {
        $item = $configurationItems[$i]
        $isLastItem = ($i -eq $configurationItems.Count - 1)
        $itemPrefix = if ($isLastItem) { "└── " } else { "├── " }
        $newPrefix = if ($isLastItem) { "    " } else { "│   " }

        if ($item.PSIsContainer) {
            $subItems = Get-TreeView -Path $item.FullName -Prefix "$Prefix$newPrefix" -configurationPatterns $configurationPatterns -IsLast $isLastItem -TotalDirCount $TotalDirCount -TotalFileCount $TotalFileCount
            if ($subItems) {
                $treeView += "$Prefix$itemPrefix$($item.Name)"
                $treeView += $subItems
                $localDirCount++
                $TotalDirCount.Value++
            }
        } else {
            $treeView += "$Prefix$itemPrefix$($item.Name)"
            $localFileCount++
            $TotalFileCount.Value++
        }
    }

    return $treeView
}

function Test-IsBinaryFile {
    param([string]$FilePath)
    try {
        $file = [System.IO.File]::OpenRead($FilePath)
        $bytes = New-Object byte[] 1024
        $bytesRead = $file.Read($bytes, 0, 1024)
        $file.Close()
        
        if ($bytesRead -eq 0) {
            return $false  # Empty file, treat as non-binary
        }
        
        for ($i = 0; $i -lt $bytesRead; $i++) {
            if ($bytes[$i] -eq 0) {
                return $true  # File contains null byte, likely binary
            }
        }
        
        $nonPrintable = $bytes[0..($bytesRead-1)] | Where-Object { $_ -lt 32 -and $_ -ne 9 -and $_ -ne 10 -and $_ -ne 13 }
        return ($nonPrintable.Count / $bytesRead) -gt 0.3  # More than 30% non-printable characters
    }
    catch {
        Write-Host "Error checking file $FilePath : $_"
        return $true  # Assume binary if we can't read the file
    }
}

function Get-FileContents {
    param(
        [string]$Path,
        [array]$configurationPatterns
    )
    $items = Get-ChildItem -Path $Path -Recurse -File
    $fileContents = @()
    foreach ($item in $items) {
        if (Test-ConfigurationPath -Path $item.FullName -configurationPatterns $configurationPatterns) {
            $relativePath = $item.FullName.Substring($RepoPath.Length).TrimStart('\', '/').Replace('\', '/')
            $fileContent = @()
            $fileContent += "### $relativePath"
            
            if (Test-IsBinaryFile -FilePath $item.FullName) {
                Write-Host "Skipping binary file: $relativePath"
                $fileContent += "[Binary file content not included]"
            } else {
                $fileContent += $backticks
                $extension = [System.IO.Path]::GetExtension($item.Name).TrimStart('.')
                if ($extension) {
                    $fileContent[-1] = "$backticks$extension"
                }
                
                try {
                    $content = Get-Content $item.FullName -Raw -ErrorAction Stop
                    if ($content.Length -gt 1000000) {  # Limit to ~1MB of text
                        $fileContent += $content.Substring(0, 1000000)
                        $fileContent += "`n... [Content truncated due to length]"
                    } else {
                        $fileContent += $content
                    }
                }
                catch {
                    Write-Host "Error reading file $relativePath : $_"
                    $fileContent += "[Error reading file content]"
                }
                
                $fileContent += $backticks
            }
            
            $fileContent += ""
            $fileContents += $fileContent
        }
    }
    return $fileContents
}

# Main script
Write-Host "Script started. Repository path: $RepoPath"
$configurationPatterns = Get-ConfigurationPatterns -RepoPath $RepoPath

if ($configurationPatterns.Count -eq 0) {
    Write-Error "No repo_documenter.config file found or it's empty. Please create a repo_documenter.config file in the repository root."
    exit 1
}

# Generate tree view
Write-Host "Generating tree view..."
"# Project: $projectName" | Out-File $OutputFile
"`n## Structure:" | Add-Content $OutputFile
$backticks | Add-Content $OutputFile
$totalDirCount = 0
$totalFileCount = 0
$treeView = Get-TreeView -Path $RepoPath -configurationPatterns $configurationPatterns -TotalDirCount ([ref]$totalDirCount) -TotalFileCount ([ref]$totalFileCount)
$treeView | Add-Content $OutputFile
$backticks | Add-Content $OutputFile
"`n$totalDirCount director$(if($totalDirCount -ne 1){'ies'}else{'y'}), $totalFileCount file$(if($totalFileCount -ne 1){'s'})" | Add-Content $OutputFile

Write-Host "Tree view generated. Total directories: $totalDirCount, total files: $totalFileCount"

# Append file contents
Write-Host "Aggregating file contents..."
"`n## File Contents:" | Add-Content $OutputFile
Get-FileContents -Path $RepoPath -configurationPatterns $configurationPatterns | Add-Content $OutputFile

Write-Host "Aggregation complete. Output: $OutputFile"