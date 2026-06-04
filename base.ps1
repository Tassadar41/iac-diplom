# ═══════════════════════════════════════════
#  ВПИШИТЕ СЮДА СВОИ СКРИПТЫ (полные пути)
# ═══════════════════════════════════════════
$ScriptList = @(
    "./terraform_deploy.ps1",
    "./bastion_deploy.ps1"
    "./monitoring_deploy.ps1",
    "./master_deploy.ps1",
    "./worker_deploy.ps1",
    "./app_deploy.ps1"
)
# ═══════════════════════════════════════════

# Проверяем, что все файлы существуют (предупреждение, а не ошибка)
foreach ($path in $ScriptList) {
    if (-not (Test-Path -Path $path -PathType Leaf)) {
        Write-Warning "File '$path' not found, menu item will be shown but launch may fail."
    }
}

while ($true) {
    Clear-Host
    Write-Host "===== My scripts =====" -ForegroundColor Cyan

    for ($i = 0; $i -lt $ScriptList.Count; $i++) {
        # Показываем только имя файла, а не весь путь, для чистоты
        $fileName = Split-Path -Path $ScriptList[$i] -Leaf
        Write-Host "$($i+1). $fileName" -ForegroundColor Yellow
    }
    $exitIndex = $ScriptList.Count + 1
    Write-Host "$exitIndex. Exit" -ForegroundColor Green

    $input = Read-Host "`nEnter the script number to run"

    if ($input -notmatch '^\d+$') {
        Write-Host "Error: Please enter an integer." -ForegroundColor Red
        Pause
        continue
    }
    $num = [int]$input

    if ($num -eq $exitIndex) {
        break
    }
    elseif ($num -ge 1 -and $num -le $ScriptList.Count) {
        $selectedPath = $ScriptList[$num - 1]
        Write-Host "I'm launching '$selectedPath'..." -ForegroundColor White
        # Запуск PowerShell-скрипта. Если нужно запускать и .bat, .exe, можно заменить на Start-Process.
        & $selectedPath
        Write-Host "`nThe script has completed. To return to the menu, press Enter..." -ForegroundColor Gray
        Pause
    }
    else {
        Write-Host "Invalid number. Valid values ​​are from 1 to $($ScriptList.Count) or $exitIndex for exit." -ForegroundColor Red
        Pause
    }
}

Write-Host "Exiting from menu." -ForegroundColor Green