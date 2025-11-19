<#
 # Прорверим, если установленные необходимые инструменты 
 #>
function Test-CommandExists {
    param ($command)
    try {
        if (Get-Command $command -ErrorAction Stop) {
            return $true
        }
    }
    catch {
        return $false
    }
}

# Метод для проверки ImageMagick
function Test-ImageMagick {
    return Test-CommandExists "magick" 
}

# Метод для проверки Ghostscript
function Test-Ghostscript {
    # Check for various Ghostscript executable names across platforms
    $gsWin64 = Test-CommandExists "gswin64c"  # 64-bit Windows version
    $gsWin32 = Test-CommandExists "gswin32c"  # 32-bit Windows version
    $gs = Test-CommandExists "gs"              # Common name on all platforms
    $gsUnix = Test-CommandExists "gsc"         # Unix version

    return $gsWin64 -or $gsWin32 -or $gs -or $gsUnix
}

# Метод для проверки git
function Test-Git {
    return Test-CommandExists "git"
}

# Метод для установки необходимых инструментов при их отсутствии
# Для установки используется Chocolatey
function Install-RequiredTools {
    # First, verify if Chocolatey is installed
    if (-not (Test-CommandExists "choco")) {
        Write-Host "Chocolatey не найден. Устанавливаем Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }

    # Установим ImageMagick, если отсутствует
    if (-not (Test-ImageMagick)) {
        Write-Host "Устанавливаем ImageMagick..."
        choco install imagemagick -y
    }

    # Установим Ghostscript, если отсутствует
    if (-not (Test-Ghostscript)) {
        Write-Host "Устанавливаем Ghostscript..."
        choco install ghostscript -y
    }

    # Установим git, если отсутствует 
    if (-not (Test-Git)) {
        Write-Host "Устанавливаем Git..."
        choco install git -y
    }
}

# Основная функция для проверки или установки необходимых инструментов
function Test-RequiredTools {
    Write-Host "Проверяем необходимые инструменты..."

    $hasImageMagick = Test-ImageMagick
    $hasGhostscript = Test-Ghostscript
    $hasGit = Test-Git 

    Write-Host "ImageMagick установлен: $hasImageMagick"
    Write-Host "Ghostscript установлен: $hasGhostscript"
    Write-Host "Git установлен: $hasGit"

    if (-not ($hasImageMagick -and $hasGhostscript)) {
        $installChoice = Read-Host "Хотите установить отсутствующие инструменты? (Y/N)"
        if ($installChoice -eq 'Y') {
            Install-RequiredTools
            return $true
        } else {
            Write-Host "Пожалуйста, установите отсутствующие инструменты вручную для использования этого скрипта."
            Write-Host "Вы можете установить их с помощью:"
            Write-Host "- Chocolatey (рекомендуется):"
            Write-Host "  choco install imagemagick ghostscript -y"
            Write-Host "- Или загрузить установщики с:"
            Write-Host "  ImageMagick: https://imagemagick.org/script/download.php"
            Write-Host "  Ghostscript: https://ghostscript.com/releases/gsdnld.html"
            return $false
        }
    }

    return Test-ImageMagick -and Test-Ghostscript -and Test-Git
}

function Get-ToolCommand {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('ImageMagick', 'GhostScript')]
        [string]$Tool
    )

    switch ($Tool) {
        'ImageMagick' {
            # Check for different ImageMagick commands in order of preference
            try {
                $cmdPath = Get-Command 'magick' -ErrorAction Stop
                return $cmdPath.Name
            } catch {
                throw "ImageMagick не установленна или не в PATH"
            }
        }
        'GhostScript' {
            # Check for different Ghostscript commands in order of preference
            $commands = @('gswin64c', 'gs', 'gsc')
            foreach ($cmd in $commands) {
                try {
                    $cmdPath = Get-Command $cmd -ErrorAction Stop
                    return $cmdPath.Name
                } catch {
                    continue
                }
            }
            throw "GhostScript не установленна или не в PATH"
        }
    }
}

# Cross-platform PowerShell process starter
function Get-CrossPlatformPwsh {
    # Detect the operating system and set the appropriate PowerShell executable
    if ($IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6 -and [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)) {
        # Windows - use powershell.exe or pwsh.exe
        $pwshPath = (Get-Command "pwsh.exe" -ErrorAction SilentlyContinue) ? "pwsh.exe" : "powershell.exe"
    }
    elseif ($IsLinux -or $IsMacOS -or ($PSVersionTable.PSVersion.Major -ge 6)) {
        # Linux/macOS - use pwsh
        $pwshPath = "pwsh"
    }
    else {
        # Fallback detection
        $pwshPath = (Get-Command "pwsh" -ErrorAction SilentlyContinue) ? "pwsh" : "powershell"
    }
    
    Write-Host "Имя команды-интерпретатора PowerShell: $pwshPath"
    
    return $pwshPath
}

# Function to write error and exit with failure
function Exit-WithError {
    param([string]$Message)
    Write-Error $Message
    exit 1
}


Export-ModuleMember -Function Test-RequiredTools, Get-ToolCommand, Get-CrossPlatformPwsh, Exit-WithError, Test-CommandExists, Test-ImageMagick, Test-Ghostscript, Test-Git, Install-RequiredTools