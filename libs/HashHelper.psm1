Import-Module (Join-Path $PSScriptRoot "ToolsHelper.psm1") -Force

function Test-Blake3 {
    return Test-CommandExists "b3sum"
}

function Install-Blake3 {
    if (Test-Blake3) {
        Write-Verbose "b3sum уже установлен"
        return $true
    }

    Write-Host "Устанавливаем Blake3 (b3sum)..."
    
    try {
        if ($IsWindows) {
            # Try Chocolatey first
            if (Test-CommandExists "choco") {
                Write-Host "Установка через Chocolatey..."
                $process = Start-Process -FilePath "choco" -ArgumentList "install", "b3sum", "-y" -Wait -PassThru -NoNewWindow
                if ($process.ExitCode -eq 0) {
                    Write-Host "Blake3 успешно установлен через Chocolatey"
                    return $true
                }
            }
            
            # Try winget as fallback
            if (Test-CommandExists "winget") {
                Write-Host "Установка через winget..."
                $process = Start-Process -FilePath "winget" -ArgumentList "install", "BLAKE3-Team.BLAKE3", "--accept-source-agreements", "--accept-package-agreements" -Wait -PassThru -NoNewWindow
                if ($process.ExitCode -eq 0) {
                    Write-Host "Blake3 успешно установлен через winget"
                    return $true
                }
            }
        } elseif ($IsMacOS) {
            # Try Homebrew on macOS
            if (Test-CommandExists "brew") {
                Write-Host "Установка через Homebrew..."
                $process = Start-Process -FilePath "brew" -ArgumentList "install", "b3sum" -Wait -PassThru -NoNewWindow
                if ($process.ExitCode -eq 0) {
                    Write-Host "Blake3 успешно установлен через Homebrew"
                    return $true
                }
            }
        } else {
            # Try common Linux package managers
            if (Test-CommandExists "apt-get") {
                Write-Host "Установка через apt-get..."
                $process = Start-Process -FilePath "sudo" -ArgumentList "apt-get", "install", "-y", "b3sum" -Wait -PassThru -NoNewWindow
                if ($process.ExitCode -eq 0) {
                    Write-Host "Blake3 успешно установлен через apt-get"
                    return $true
                }
            } elseif (Test-CommandExists "yum") {
                Write-Host "Установка через yum..."
                $process = Start-Process -FilePath "sudo" -ArgumentList "yum", "install", "-y", "b3sum" -Wait -PassThru -NoNewWindow
                if ($process.ExitCode -eq 0) {
                    Write-Host "Blake3 успешно установлен через yum"
                    return $true
                }
            } elseif (Test-CommandExists "dnf") {
                Write-Host "Установка через dnf..."
                $process = Start-Process -FilePath "sudo" -ArgumentList "dnf", "install", "-y", "b3sum" -Wait -PassThru -NoNewWindow
                if ($process.ExitCode -eq 0) {
                    Write-Host "Blake3 успешно установлен через dnf"
                    return $true
                }
            }
        }
        
        Write-Warning "Не удалось установить Blake3 автоматически. Пожалуйста, установите b3sum вручную."
        Write-Host "Инструкции по установке: https://github.com/BLAKE3-team/BLAKE3/tree/master/b3sum"
        return $false
    }
    catch {
        Write-Warning "Ошибка при установке Blake3: $_"
        return $false
    }
}

function Get-Blake3Hash {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        throw "Файл не найден: $FilePath"
    }
    
    if (-not (Test-Blake3)) {
        Write-Host "Blake3 (b3sum) не найден. Попытка установки..."
        if (-not (Install-Blake3)) {
            throw "Blake3 (b3sum) не установлен и не может быть установлен автоматически"
        }
    }
    
    try {
        $outputFile = [System.IO.Path]::GetTempFileName()
        $process = Start-Process -FilePath "b3sum" -ArgumentList $FilePath -Wait -PassThru -NoNewWindow -RedirectStandardOutput $outputFile
        
        if ($process.ExitCode -ne 0) {
            Remove-Item $outputFile -ErrorAction SilentlyContinue
            throw "Ошибка при вычислении Blake3 хеша для файла: $FilePath"
        }
        
        $output = Get-Content $outputFile -Raw
        Remove-Item $outputFile -ErrorAction SilentlyContinue
        
        # b3sum выводит результат в формате "hash  filename"
        # Извлекаем только хеш
        $hash = ($output -split '\s+')[0]
        
        if ([string]::IsNullOrWhiteSpace($hash)) {
            throw "Не удалось получить хеш для файла: $FilePath"
        }
        
        return $hash.ToUpper()
    }
    catch {
        throw "Ошибка при вычислении Blake3 хеша: $_"
    }
}

function Ensure-Blake3Available {
    if (-not (Test-Blake3)) {
        Write-Host "Blake3 (b3sum) не найден. Установка..."
        if (-not (Install-Blake3)) {
            throw "Blake3 (b3sum) требуется для работы системы, но не может быть установлен автоматически"
        }
    }
    
    Write-Verbose "Blake3 (b3sum) доступен"
    return $true
}

Export-ModuleMember -Function Test-Blake3, Install-Blake3, Get-Blake3Hash, Ensure-Blake3Available