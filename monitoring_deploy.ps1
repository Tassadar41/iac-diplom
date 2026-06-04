
Push-Location -Path "setup-scripts" -ErrorAction Stop

try {
    Write-Host "=== Obtaining the external IP of a vm-monitoring machine ==="
    $instanceJson = yc compute instance get --name vm-monitoring --format json 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "YC compute instance get failed. Check that the YC CLI is configured."
    }
    $instance = $instanceJson | ConvertFrom-Json
    $vmIp = $instance.network_interfaces[0].primary_v4_address.one_to_one_nat.address
    if (-not $vmIp) {
        throw "The vm-monitoring machine does not have an external IP (one-to-one NAT)."
    }
    Write-Host "IP found: $vmIp"

    $keyPath = "$env:USERPROFILE\.ssh\oslogin_key"
    if (-not (Test-Path $keyPath)) {
        throw "SSH key not found: $keyPath"
    }

    if (-not (Test-Path "setup-monitoring.sh")) {
        throw "The file setup-monitoring.sh was not found in the current directory."
    }

    Write-Host "=== Copy setup-monitoring.sh to $vmIp ==="
    # Копируем ОБА файла одной командой
    scp -i $keyPath "setup-monitoring.sh" "yc-user@${vmIp}:~/"
    scp -i $keyPath "registries.conf" "yc-user@${vmIp}:~/"
    if ($LASTEXITCODE -ne 0) {
        throw "Error copying file via scp."
    }

    Write-Host "=== Connecting to $vmIp and execution of commands ==="
    # Команды выполняются последовательно, при ошибке остановка.
    # Сначала обновление пакетов, затем установка python3-pip и podman-compose,
    # далее запуск скрипта setup-bastion.sh, после чего удаление скопированного файла.
    $remoteCommands = @(
        "sudo fuser -k /var/lib/dpkg/lock-frontend /var/cache/debconf/config.dat 2>/dev/null; sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/debconf/config.dat; sudo DEBIAN_FRONTEND=noninteractive dpkg --configure -a --force-confold",
        "sudo rm -f /etc/apt/sources.list.d/influx*; sudo rm -f /etc/apt/trusted.gpg.d/influx*",
        "sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys DA61C26A0585BD3B",
        "sudo DEBIAN_FRONTEND=noninteractive apt-get update -o DPkg::Lock::Timeout=60",
        "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::='--force-confold' -o DPkg::Lock::Timeout=60 python3-pip",
        "sudo pip3 install podman-compose",
        "sudo mkdir -p /etc/containers/",
        "sudo mv ~/registries.conf /etc/containers/",
        "sudo bash setup-monitoring.sh",
        "rm ~/setup-monitoring.sh",
        "sudo ip route add 10.100.0.0/16 via 10.0.0.10"
    ) -join " && "
    

    ssh -i $keyPath "yc-user@$vmIp" $remoteCommands
    if ($LASTEXITCODE -ne 0) {
        throw "Error executing commands on remote machine."
    }

    Write-Host "=== All operations completed successfully ==="
}
catch {
    Write-Error "Critical error: $_"
}
finally {
    Pop-Location
    Write-Host "Current directory: $PWD"
}