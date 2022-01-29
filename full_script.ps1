$settingsObject = Get-Content -Path .\settings.json | ConvertFrom-Json

foreach ($t in $settingsObject.foldersToProcess) {
    & ".\script.ps1" $t
}

& ".\html_generator.ps1"