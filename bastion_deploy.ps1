# Сохраняем корневую директорию, чтобы вернуться в неё в конце
$ProjectRoot = Get-Location

try {
    # Шаг 1: переходим в папку setup-scripts
    $SetupScriptsDir = Join-Path -Path $ProjectRoot -ChildPath "setup-scripts"
    if (-not (Test-Path -Path $SetupScriptsDir -PathType Container)) {
        Write-Error "Foleder 'setup-scripts' not found in $ProjectRoot"
        exit 1
    }
    Set-Location -Path $SetupScriptsDir

    # Шаг 2: получаем внешний IP Bastion
    Write-Host "Obtaining an external IP address for Bastion..."
    $bastion = yc compute instance get --name bastion --format json | ConvertFrom-Json
    $bastionExternalIp = $bastion.network_interfaces[0].primary_v4_address.one_to_one_nat.address
    if (-not $bastionExternalIp) {
        Write-Error "Unable to determine external IP of Bastion"
        exit 1
    }
    Write-Host "Bastion external IP: $bastionExternalIp"

    # Шаг 3: получаем внутренние IP master-1, master-2 и monitoring
    Write-Host "Obtaining internal IPs for master-1, master-2, and monitoring..."
    $master1 = yc compute instance get --name k8s-master-1 --format json | ConvertFrom-Json
    $master1Ip = $master1.network_interfaces[0].primary_v4_address.address
    $master2 = yc compute instance get --name k8s-master-2 --format json | ConvertFrom-Json
    $master2Ip = $master2.network_interfaces[0].primary_v4_address.address
    $monitoring = yc compute instance get --name vm-monitoring --format json | ConvertFrom-Json
    $monitoringIp = $monitoring.network_interfaces[0].primary_v4_address.address

    Write-Host "master-1: $master1Ip"
    Write-Host "master-2: $master2Ip"
    Write-Host "monitoring: $monitoringIp"

    # Шаг 4: меняем IP в файле setup-bastion.sh, сохраняя порты
    $bashScript = "setup-bastion.sh"
    if (-not (Test-Path -Path $bashScript -PathType Leaf)) {
        Write-Error "File $bashScript not found in this directory"
        exit 1
    }

    Write-Host "Update IP addresses in $bashScript..."
    $content = Get-Content -Path $bashScript -Raw

    # Заменяем IP для monitoring (порт 3000)
    $content = $content -replace '(server monitoring\s+)[\d.]+(:3000)', "`${1}$monitoringIp`${2}"
    # Заменяем IP для master-1 (порт 6443)
    $content = $content -replace '(server master-1\s+)[\d.]+(:6443)', "`${1}$master1Ip`${2}"
    # Заменяем IP для master-2 (порт 6443)
    $content = $content -replace '(server master-2\s+)[\d.]+(:6443)', "`${1}$master2Ip`${2}"

    Set-Content -Path $bashScript -Value $content -NoNewline

    # Шаг 5: отправляем файл на Bastion по SCP
    $sshKey = "$env:USERPROFILE\.ssh\oslogin_key"
    if (-not (Test-Path -Path $sshKey)) {
        Write-Error "SSH-key not found: $sshKey"
        exit 1
    }

    Write-Host "Copy $bashScript on Bastion..."
    $scpArgs = @(
        '-i', $sshKey,
        $bashScript,
        "yc-user@${bastionExternalIp}:~/"
    )
    & scp.exe @scpArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Error copying file via SCP"
    }

    # Шаг 6–8: подключаемся по SSH и запускаем скрипт, затем сессия завершается
    Write-Host "Launching $bashScript on Bastion..."
    $sshArgs = @(
        '-i', $sshKey,
        "yc-user@$bastionExternalIp",
        'sudo bash ~/setup-bastion.sh && rm ~/setup-bastion.sh'
    )
    & ssh.exe @sshArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Error executing script on Bastion"
    }
    Write-Host "The script was successfully executed on Bastion."
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
finally {
    # Шаг 9: возвращаемся в корень проекта
    Set-Location -Path $ProjectRoot
    Write-Host "Returned to the root project folder: $ProjectRoot"
}