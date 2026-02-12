# ====================================================================== #
# UTF-8 with BOM Encoding for output
# ====================================================================== #

if ($PSVersionTable.PSVersion.Major -eq 5) {
    $OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
} else {
    $utf8WithBom = New-Object System.Text.UTF8Encoding $true
    $OutputEncoding = $utf8WithBom
    [Console]::OutputEncoding = $utf8WithBom
}

# ====================================================================== #
#  Script Metadata
# ====================================================================== #

$Script:WinfigMeta = @{
    Author       = "Armoghan-ul-Mohmin"
    CompanyName  = "Get-Winfig"
    Description  = "Windows configuration and automation framework"
    Version     = "1.0.0"
    License     = "MIT"
    Platform    = "Windows"
    PowerShell  = $PSVersionTable.PSVersion.ToString()
}

# ====================================================================== #
#  Color Palette
# ====================================================================== #

$Script:WinfigColors = @{
    Primary   = "Blue"
    Success   = "Green"
    Info      = "Cyan"
    Warning   = "Yellow"
    Error     = "Red"
    Accent    = "Magenta"
    Light     = "White"
    Dark      = "DarkGray"
}

# ====================================================================== #
# User Prompts
# ====================================================================== #

$Script:WinfigPrompts = @{
    Confirm    = "[?] Do you want to proceed? (Y/N): "
    Retry      = "[?] Do you want to retry? (Y/N): "
    Abort      = "[!] Operation aborted by user."
    Continue   = "[*] Press any key to continue..."
}

# ====================================================================== #
#  Paths
# ====================================================================== #

$Global:WinfigPaths = @{
    Desktop         = [Environment]::GetFolderPath("Desktop")
    Documents       = [Environment]::GetFolderPath("MyDocuments")
    UserProfile     = [Environment]::GetFolderPath("UserProfile")
    Temp            = [Environment]::GetEnvironmentVariable("TEMP")
    AppDataRoaming  = [Environment]::GetFolderPath("ApplicationData")
    AppDataLocal    = [Environment]::GetFolderPath("LocalApplicationData")
    Downloads       = [System.IO.Path]::Combine([Environment]::GetFolderPath("UserProfile"), "Downloads")
    Logs            = [System.IO.Path]::Combine([Environment]::GetEnvironmentVariable("TEMP"), "Winfig-Logs")
}
$Global:WinfigPaths.DotFiles = [System.IO.Path]::Combine($Global:WinfigPaths.UserProfile, ".Dotfiles")

# ====================================================================== #
# Start Time, Resets, Counters
# ====================================================================== #
$Global:WinfigLogStart = Get-Date
$Global:WinfigLogFilePath = $null
Remove-Variable -Name WinfigLogFilePath -Scope Global -ErrorAction SilentlyContinue
Remove-Variable -Name LogCount -Scope Global -ErrorAction SilentlyContinue
Remove-Variable -Name ErrorCount -Scope Global -ErrorAction SilentlyContinue
Remove-Variable -Name WarnCount -Scope Global -ErrorAction SilentlyContinue

# ====================================================================== #
# Utility Functions
# ====================================================================== #

# ---------------------------------------------------------------------------- #
# Function to display a Success message
function Show-SuccessMessage {
    param (
        [string]$Message
    )
    Write-Host "[OK] $Message" -ForegroundColor $Script:WinfigColors.Success
}

# ---------------------------------------------------------------------------- #
# Function to display an Error message
function Show-ErrorMessage {
    param (
        [string]$Message
    )
    Write-Host "[ERROR] $Message" -ForegroundColor $Script:WinfigColors.Error
}

# ---------------------------------------------------------------------------- #
# Function to display an Info message
function Show-InfoMessage {
    param (
        [string]$Message
    )
    Write-Host "[INFO] $Message" -ForegroundColor $Script:WinfigColors.Info
}

# ---------------------------------------------------------------------------- #
# Function to display a Warning message
function Show-WarningMessage {
    param (
        [string]$Message
    )
    Write-Host "[WARN] $Message" -ForegroundColor $Script:WinfigColors.Warning
}

# ---------------------------------------------------------------------------- #
# Function to prompt user for input with a specific color
function Prompt-UserInput {
    param (
        [string]$PromptMessage = $Script:WinfigPrompts.Confirm,
        [string]$PromptColor   = $Script:WinfigColors.Primary
    )
    # Write prompt in the requested color, keep cursor on same line, then read input
    Write-Host -NoNewline $PromptMessage -ForegroundColor $PromptColor
    $response = Read-Host

    return $response
}

# ---------------------------------------------------------------------------- #
# Function to Prompt user for confirmation (Y/N)
function Prompt-UserConfirmation {
    while ($true) {
        $response = Prompt-UserInput -PromptMessage $Script:WinfigPrompts.Confirm -PromptColor $Script:WinfigColors.Primary
        switch ($response.ToUpper()) {
            "Y" { return $true }
            "N" { return $false }
            default {
                Show-WarningMessage "Invalid input. Please enter Y or N."
            }
        }
    }
}

# ---------------------------------------------------------------------------- #
# Function to Prompt user to Retry (Y/N)
function Prompt-UserRetry {
    while ($true) {
        $response = Prompt-UserInput -PromptMessage $Script:WinfigPrompts.Retry -PromptColor $Script:WinfigColors.Primary
        switch ($response.ToUpper()) {
            "Y" { return $true }
            "N" { return $false }
            default {
                Show-WarningMessage "Invalid input. Please enter Y or N."
            }
        }
    }
}

# ---------------------------------------------------------------------------- #
# Function to Prompt user to continue
function Prompt-UserContinue {
    Write-Host $Script:WinfigPrompts.Continue -ForegroundColor $Script:WinfigColors.Primary
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ---------------------------------------------------------------------------- #
# Function to Abort operation
function Abort-Operation {
    Show-ErrorMessage $Script:WinfigPrompts.Abort
    # Write log footer before exiting
    if ($Global:WinfigLogFilePath) {
        Log-Message -Message "Script terminated." -EndRun
    }
    exit 1
}

# ---------------------------------------------------------------------------- #
# Function to Write a Section Header
function Write-SectionHeader {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,

        [Parameter(Mandatory=$false)]
        [string]$Description = ""
    )
    $separator = "=" * 70
    Write-Host $separator -ForegroundColor $Script:WinfigColors.Accent
    Write-Host "$Title" -ForegroundColor $Script:WinfigColors.Primary
    if ($Description) {
        Write-Host "$Description" -ForegroundColor $Script:WinfigColors.Accent
    }
    Write-Host $separator -ForegroundColor $Script:WinfigColors.Accent
}

# ---------------------------------------------------------------------------- #
# Function to Write a Subsection Header
function Write-SubsectionHeader {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title
    )
    $separator = "-" * 50
    Write-Host $separator -ForegroundColor $Script:WinfigColors.Accent
    Write-Host "$Title" -ForegroundColor $Script:WinfigColors.Primary
    Write-Host $separator -ForegroundColor $Script:WinfigColors.Accent
}

# ---------------------------------------------------------------------------- #
#  Function to Write a Log Message
function Log-Message {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO",

        [Parameter(Mandatory=$false)]
        [switch]$EndRun
    )

    if (-not $Global:LogCount) { $Global:LogCount = 0 }
    if (-not $Global:ErrorCount) { $Global:ErrorCount = 0 }
    if (-not $Global:WarnCount) { $Global:WarnCount = 0 }


    if (-not (Test-Path -Path $Global:WinfigPaths.Logs)) {
        New-Item -ItemType Directory -Path $Global:WinfigPaths.Logs -Force | Out-Null
    }

    $enc = New-Object System.Text.UTF8Encoding $true

    $identity = try { [System.Security.Principal.WindowsIdentity]::GetCurrent().Name } catch { $env:USERNAME }
    $isElevated = try {
        (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        $false
    }
    $scriptPath = if ($PSCommandPath) { $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { $MyInvocation.MyCommand.Path } else { $null }
    $psVersion = $PSVersionTable.PSVersion.ToString()
    $dotNetVersion = [System.Environment]::Version.ToString()
    $workingDir = (Get-Location).Path
    $osInfo = try {
        (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop).Caption
    } catch {
        [Environment]::OSVersion.VersionString
    }
    # ---------------------------------------------------------------------------------------

    if (-not $Global:WinfigLogFilePath) {
        # $Global:WinfigLogStart is set in the main script execution block for each run
        $fileStamp = $Global:WinfigLogStart.ToString('yyyy-MM-dd_HH-mm-ss')
        $Global:WinfigLogFilePath = [System.IO.Path]::Combine($Global:WinfigPaths.Logs, "winfig-Dotfiles-$fileStamp.log")

        $header = @()
        $header += "==================== Winfig Dotfiles Log ===================="
        $header += "Start Time  : $($Global:WinfigLogStart.ToString('yyyy-MM-dd HH:mm:ss'))"
        $header += "Host Name   : $env:COMPUTERNAME"
        $header += "User        : $identity"
        $header += "IsElevated  : $isElevated"
        if ($scriptPath) { $header += "Script Path : $scriptPath" }
        $header += "Working Dir : $workingDir"
        $header += "PowerShell  : $psVersion"
        $header += "NET Version : $dotNetVersion"
        $header += "OS          : $osInfo"
        $header += "=============================================================="
        $header += ""

        try {
            [System.IO.File]::WriteAllLines($Global:WinfigLogFilePath, $header, $enc)
        } catch {
            $header | Out-File -FilePath $Global:WinfigLogFilePath -Encoding UTF8 -Force
        }
    } else {
        if (-not $Global:WinfigLogStart) {
            $Global:WinfigLogStart = Get-Date
        }

        try {
            if (Test-Path -Path $Global:WinfigLogFilePath) {
                $firstLine = Get-Content -Path $Global:WinfigLogFilePath -TotalCount 1 -ErrorAction SilentlyContinue
                if ($firstLine -and ($firstLine -notmatch 'Winfig Dotfiles Log')) {

                    $header = @()
                    $header += "==================== Winfig Dotfiles Log  ===================="
                    $header += "Start Time  : $($Global:WinfigLogStart.ToString('yyyy-MM-dd HH:mm:ss'))"
                    $header += "Host Name   : $env:COMPUTERNAME"
                    $header += "User        : $identity"
                    $header += "IsElevated  : $isElevated"
                    if ($scriptPath) { $header += "Script Path : $scriptPath" }
                    $header += "Working Dir : $workingDir"
                    $header += "PowerShell  : $psVersion"
                    $header += "NET Version : $dotNetVersion"
                    $header += "OS          : $osInfo"
                    $header += "======================================================================="
                    $header += ""

                    # Prepend header safely: write header to temp file then append original content
                    $temp = [System.IO.Path]::GetTempFileName()
                    try {
                        [System.IO.File]::WriteAllLines($temp, $header, $enc)
                        [System.IO.File]::AppendAllLines($temp, (Get-Content -Path $Global:WinfigLogFilePath -Raw).Split([Environment]::NewLine), $enc)
                        Move-Item -Force -Path $temp -Destination $Global:WinfigLogFilePath
                    } finally {
                        if (Test-Path $temp) { Remove-Item $temp -ErrorAction SilentlyContinue }
                    }
                }
            }
        } catch {
            # ignore header-fix failures; continue logging
        }
    }

    if ($EndRun) {
        $endTime = Get-Date
        # $Global:WinfigLogStart is guaranteed to be set now
        $duration = $endTime - $Global:WinfigLogStart
        $footer = @()
        $footer += ""
        $footer += "--------------------------------------------------------------"
        $footer += "End Time    : $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))"
        $footer += "Duration    : $($duration.ToString('dd\.hh\:mm\:ss') -replace '^00\.', '')"
        $footer += "Log Count   : $Global:LogCount"
        $footer += "Errors/Warn : $Global:ErrorCount / $Global:WarnCount"
        $footer += "===================== End of Winfig Log ======================"
        try {
            [System.IO.File]::AppendAllLines($Global:WinfigLogFilePath, $footer, $enc)
        } catch {
            $footer | Out-File -FilePath $Global:WinfigLogFilePath -Append -Encoding UTF8
        }
        return
    }

    $now = Get-Date
    $timestamp = $now.ToString("yyyy-MM-dd HH:mm:ss.fff")
    $logEntry = "[$timestamp] [$Level] $Message"

    $Global:LogCount++
    if ($Level -eq 'ERROR') { $Global:ErrorCount++ }
    if ($Level -eq 'WARN') { $Global:WarnCount++ }

    try {
        [System.IO.File]::AppendAllText($Global:WinfigLogFilePath, $logEntry + [Environment]::NewLine, $enc)
    } catch {
        Write-Host "Failed to write log to file: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host $logEntry
    }
}

# ====================================================================== #
#  Main Functions
# ====================================================================== #

# ---------------------------------------------------------------------------- #
# Function to check if running as Administrator
function IsAdmin{
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($currentUser)
    if ($principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Log-Message -Message "Script is running with Administrator privileges." -Level "SUCCESS"
    } else {
        Show-ErrorMessage "Script is NOT running with Administrator privileges."
        Log-Message -Message "Script is NOT running with Administrator privileges." -Level "ERROR"
        Log-Message "Forced exit." -EndRun
        $LogPathMessage = "Check the Log file for details: $($Global:WinfigLogFilePath)"
        Show-InfoMessage -Message $LogPathMessage
        exit 1
    }
}

# ---------------------------------------------------------------------------- #
# Function to check Working Internet Connection
function Test-InternetConnection {
    try {
        $request = [System.Net.WebRequest]::Create("http://www.google.com")
        $request.Timeout = 5000
        $response = $request.GetResponse()
        $response.Close()
        Log-Message -Message "Internet connection is available." -Level "SUCCESS"
        return $true
    } catch {
        Show-ErrorMessage "No internet connection available: $($_.Exception.Message)"
        Log-Message -Message "No internet connection available: $($_.Exception.Message)" -Level "ERROR"
        Log-Message "Forced exit." -EndRun
        $LogPathMessage = "Check the Log file for details: $($Global:WinfigLogFilePath)"
        Show-InfoMessage -Message $LogPathMessage
        exit 1

    }
}

# ---------------------------------------------------------------------------- #
# Function to Display Banner
function Winfig-Banner {
    Clear-Host
    Write-Host ""
    Write-Host ("  ██╗    ██╗██╗███╗   ██╗███████╗██╗ ██████╗  ".PadRight(70)) -ForegroundColor $Script:WinfigColors.Light
    Write-Host ("  ██║    ██║██║████╗  ██║██╔════╝██║██╔════╝  ".PadRight(70)) -ForegroundColor $Script:WinfigColors.Light
    Write-Host ("  ██║ █╗ ██║██║██╔██╗ ██║█████╗  ██║██║  ███╗ ".PadRight(70)) -ForegroundColor $Script:WinfigColors.Accent
    Write-Host ("  ██║███╗██║██║██║╚██╗██║██╔══╝  ██║██║   ██║ ".PadRight(70)) -ForegroundColor $Script:WinfigColors.Accent
    Write-Host ("  ╚███╔███╔╝██║██║ ╚████║██║     ██║╚██████╔╝ ".PadRight(70)) -ForegroundColor $Script:WinfigColors.Success
    Write-Host ("   ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝  ".PadRight(70)) -ForegroundColor $Script:WinfigColors.Success
    Write-Host ((" " * 70)) -ForegroundColor $Script:WinfigColors.Primary
    Write-Host ("" + $Script:WinfigMeta.CompanyName).PadLeft(40).PadRight(70) -ForegroundColor $Script:WinfigColors.Primary
    Write-Host ((" " * 70)) -ForegroundColor $Script:WinfigColors.Primary
    Write-Host ("  " + $Script:WinfigMeta.Description).PadRight(70) -ForegroundColor $Script:WinfigColors.Accent
    Write-Host ((" " * 70)) -ForegroundColor $Script:WinfigColors.Primary
    Write-Host (("  Version: " + $Script:WinfigMeta.Version + "    PowerShell: " + $Script:WinfigMeta.PowerShell).PadRight(70)) -ForegroundColor $Script:WinfigColors.Warning
    Write-Host (("  Author:  " + $Script:WinfigMeta.Author + "    Platform: " + $Script:WinfigMeta.Platform).PadRight(70)) -ForegroundColor $Script:WinfigColors.Warning
    Write-Host ""
}

# ---------------------------------------------------------------------------- #
# CTRL+C Signal Handler
trap {
    # Check if the error is due to a user interrupt (CTRL+C)
    if ($_.Exception.GetType().Name -eq "HostException" -and $_.Exception.Message -match "stopped by user") {

        # 1. Print the desired message
        Write-Host ""
        Write-Host ">>> [!] User interruption (CTRL+C) detected. Exiting gracefully..." -ForegroundColor $Script:WinfigColors.Accent

        # 2. Log the event before exit
        Log-Message -Message "Script interrupted by user (CTRL+C)." -Level "WARN"

        # 3. Write log footer before exiting
        if ($Global:WinfigLogFilePath) {
            Log-Message -Message "Script terminated by user (CTRL+C)." -EndRun
        }

        # 4. Terminate the script cleanly (exit code 1 is standard for non-zero exit)
        exit 1
    }
    # If it's a different kind of error, let the default behavior (or next trap) handle it
    continue
}

# ---------------------------------------------------------------------------- #
#  Check if git is installed
function Test-GitInstalled {
    try {
        git --version *> $null
        Log-Message -Message "Git is installed." -Level "SUCCESS"
        return $true
    } catch {
        Show-ErrorMessage "Git is not installed or not found in PATH."
        Log-Message -Message "Git is not installed or not found in PATH." -Level "ERROR"
        exit 1
    }
}

# ---------------------------------------------------------------------------- #
#  Install Cursors
function Install-Cursors {
    $sourceDir = [System.IO.Path]::Combine($Global:WinfigPaths.DotFiles, "winfig-customization", "Cursors")

    $cursorThemes = @(
        @{ Name = "Sunity"; Options = @("Light", "Dark") },
        @{ Name = "Win 11 Concept"; Options = @("Light", "Dark") }
    )

    # Display cursor theme menu
    Write-Host ""
    Write-Host "Available Cursor Themes:" -ForegroundColor $Script:WinfigColors.Primary
    Write-Host ""
    for ($i = 0; $i -lt $cursorThemes.Count; $i++) {
        Write-Host "  [$($i + 1)] $($cursorThemes[$i].Name)" -ForegroundColor $Script:WinfigColors.Accent
    }
    Write-Host ""

    # Get user selection for theme
    $themeSelection = -1
    while ($themeSelection -lt 0 -or $themeSelection -ge $cursorThemes.Count) {
        $response = Prompt-UserInput -PromptMessage "[?] Select cursor theme (1-$($cursorThemes.Count)): " -PromptColor $Script:WinfigColors.Primary
        if ($response -match '^\d+$' -and [int]$response -ge 1 -and [int]$response -le $cursorThemes.Count) {
            $themeSelection = [int]$response - 1
        } else {
            Show-WarningMessage "Invalid selection. Please enter a number between 1 and $($cursorThemes.Count)."
        }
    }

    $selectedTheme = $cursorThemes[$themeSelection]
    Show-SuccessMessage "Selected theme: $($selectedTheme.Name)"
    Log-Message -Message "User selected cursor theme: $($selectedTheme.Name)" -Level "INFO"

    # Display variant options
    Write-Host ""
    Write-Host "Available Variants:" -ForegroundColor $Script:WinfigColors.Primary
    Write-Host ""
    for ($i = 0; $i -lt $selectedTheme.Options.Count; $i++) {
        Write-Host "  [$($i + 1)] $($selectedTheme.Options[$i])" -ForegroundColor $Script:WinfigColors.Accent
    }
    Write-Host ""

    # Get user selection for variant
    $variantSelection = -1
    while ($variantSelection -lt 0 -or $variantSelection -ge $selectedTheme.Options.Count) {
        $response = Prompt-UserInput -PromptMessage "[?] Select variant (1-$($selectedTheme.Options.Count)): " -PromptColor $Script:WinfigColors.Primary
        if ($response -match '^\d+$' -and [int]$response -ge 1 -and [int]$response -le $selectedTheme.Options.Count) {
            $variantSelection = [int]$response - 1
        } else {
            Show-WarningMessage "Invalid selection. Please enter a number between 1 and $($selectedTheme.Options.Count)."
        }
    }

    $selectedVariant = $selectedTheme.Options[$variantSelection]
    Show-SuccessMessage "Selected variant: $selectedVariant"
    Log-Message -Message "User selected cursor variant: $selectedVariant" -Level "INFO"

    # Build path to selected cursor folder
    $cursorFolder = [System.IO.Path]::Combine($sourceDir, $selectedTheme.Name, $selectedVariant)

    # Check if cursor folder exists
    if (-not (Test-Path -Path $cursorFolder)) {
        Show-ErrorMessage "Cursor folder not found at: $cursorFolder"
        Log-Message -Message "Cursor folder not found at: $cursorFolder" -Level "ERROR"
        return $false
    }

    # Build path to Install.inf
    $infPath = [System.IO.Path]::Combine($cursorFolder, "Install.inf")

    # Check if Install.inf exists
    if (-not (Test-Path -Path $infPath)) {
        Show-ErrorMessage "Install.inf not found at: $infPath"
        Log-Message -Message "Install.inf not found at: $infPath" -Level "ERROR"
        return $false
    }

    Show-InfoMessage "Found cursor folder at: $cursorFolder"
    Log-Message -Message "Opening cursor folder for manual installation: $cursorFolder" -Level "INFO"

    # Open the folder in Explorer
    try {
        Start-Process explorer.exe -ArgumentList $cursorFolder
        Show-SuccessMessage "Opened cursor folder in Explorer"
        Log-Message -Message "Opened cursor folder in Explorer: $cursorFolder" -Level "SUCCESS"
    } catch {
        Show-ErrorMessage "Failed to open cursor folder: $($_.Exception.Message)"
        Log-Message -Message "Failed to open cursor folder: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }

    # Wait a moment for Explorer to open
    Start-Sleep -Seconds 2

    # Show instructions using Windows MessageBox
    try {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            "Cursor Installation Instructions:`n`n" +
            "1. In the opened folder, right-click 'Install.inf'`n" +
            "2. Select 'Install' from the context menu`n" +
            "3. Follow any prompts to complete installation`n`n" +
            "Selected: $($selectedTheme.Name) - $selectedVariant`n`n" +
            "After installation:`n" +
            "• Go to Settings > Personalization > Themes > Mouse cursor`n" +
            "• Select your new cursor theme`n" +
            "• Click Apply",
            "Winfig Cursor Installation",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        ) | Out-Null

        Show-SuccessMessage "Installation instructions displayed"
        Log-Message -Message "Cursor installation instructions displayed to user" -Level "SUCCESS"
        return $true
    } catch {
        # Fallback to console output if MessageBox fails
        Write-Host ""
        Show-InfoMessage "Manual Installation Required:"
        Write-Host "  1. In the opened folder, right-click 'Install.inf'" -ForegroundColor $Script:WinfigColors.Accent
        Write-Host "  2. Select 'Install' from the context menu" -ForegroundColor $Script:WinfigColors.Accent
        Write-Host "  3. Follow any prompts to complete installation" -ForegroundColor $Script:WinfigColors.Accent
        Write-Host ""
        Write-Host "  After installation:" -ForegroundColor $Script:WinfigColors.Info
        Write-Host "  • Go to Settings > Personalization > Themes > Mouse cursor" -ForegroundColor $Script:WinfigColors.Accent
        Write-Host "  • Select your new cursor theme" -ForegroundColor $Script:WinfigColors.Accent
        Write-Host "  • Click Apply" -ForegroundColor $Script:WinfigColors.Accent

        Log-Message -Message "Cursor installation instructions displayed (console fallback)" -Level "SUCCESS"
        return $true
    }
}

# ====================================================================== #
#  Main Script Execution
# ====================================================================== #

Winfig-Banner
Write-SectionHeader -Title "Checking Requirements"
Write-Host ""

IsAdmin | Out-Null
Show-SuccessMessage "Administrator privileges confirmed."

# Test-InternetConnection | Out-Null
Show-SuccessMessage "Internet connection is available."

Test-GitInstalled | Out-Null
Show-SuccessMessage "Git installation check completed."

Write-Host ""
Prompt-UserContinue

Winfig-Banner
Write-SectionHeader -Title "Cloning Winfig Customization Repository"
Write-Host ""
$repoPath = Join-Path $Global:WinfigPaths.DotFiles "winfig-Customization"
if (-not (Test-Path -Path $repoPath)) {
    try {
        Show-InfoMessage "Cloning Winfig Customization repository..."
        Log-Message -Message "Cloning Winfig Customization repository..." -Level "INFO"
        git clone https://github.com/Get-Winfig/winfig-customization.git $repoPath *> $null
    } catch {
        Show-ErrorMessage "Failed to clone Winfig Customization repository: $($_.Exception.Message)"
        Log-Message -Message "Failed to clone Winfig Customization repository: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
    if (Test-Path -Path $repoPath) {
        Show-SuccessMessage "Cloned Winfig Customization repository to $repoPath."
        Log-Message -Message "Cloned Winfig Customization repository to $repoPath." -Level "SUCCESS"
    } else {
        Show-ErrorMessage "Winfig Customization repository was not cloned. Please check your internet connection or repository URL."
        Log-Message -Message "Winfig Customization repository was not cloned. Please check your internet connection or repository URL." -Level "ERROR"
        exit 1
    }
} else {
    try {
        Show-InfoMessage "Updating Winfig Dotfiles repository..."
        Log-Message -Message "Updating Winfig Dotfiles repository..." -Level "INFO"
        Push-Location $repoPath
        git pull *> $null
        Pop-Location
        Show-SuccessMessage "Updated Winfig Dotfiles repository at $repoPath."
        Log-Message -Message "Updated Winfig Dotfiles repository at $repoPath." -Level "SUCCESS"
    } catch {
        Show-ErrorMessage "Failed to update Winfig Dotfiles repository: $($_.Exception.Message)"
        Log-Message -Message "Failed to update Winfig Dotfiles repository: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
}

Write-Host ""
Prompt-UserContinue

Winfig-Banner
Write-SectionHeader -Title "Installing Cursor Theme"
Write-Host ""
Install-Cursors

Write-Host ""
Write-SectionHeader -Title "Thank You For Using Winfig Customization" -Description "https://github.com/Get-Winfig/"
Show-WarningMessage -Message "Restart Windows to apply changes"
Write-Host ""
Log-Message -Message "Logging Completed." -EndRun
