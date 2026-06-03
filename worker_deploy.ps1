# setup-k8s-worker.ps1

$originalDir = Get-Location

try{
    $scriptsDir = Join-Path $originalDir "setup-scripts"
    if (-not (Test-Path $scriptsDir)) {
        Write-Error "Folder 'setup-scripts' not found in the current directory."
        exit 1
    }
    Set-Location $scriptsDir
    Write-Host "Changed directory to: $(Get-Location)"

    do {
        $workerNum = Read-Host "Enter the worker number (1, 2, 3, ...)"
    } until ($workerNum -match '^\d+$' -and [int]$workerNum -ge 1)
    $workerName = "k8s-worker-$workerNum"
    Write-Host "Target instance: $workerName"

    if (-not (Get-Command "yc" -ErrorAction SilentlyContinue)) {
        Write-Error "Yandex Cloud CLI (yc) is not installed or not in PATH."
        exit 1
    }

    # ---- IP retrieval with fallback ----
    Write-Host "Retrieving external IP for $workerName ..."

    # Try JSON method (as in other scripts)

    $instanceJson = yc compute instance get --name $workerName --format json 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "YC compute instance get failed. Check that the YC CLI is configured."
    }
    $instance = $instanceJson | ConvertFrom-Json
    $vmIp = $instance.network_interfaces[0].primary_v4_address.one_to_one_nat.address
    if (-not $vmIp) {
        throw "The vm-monitoring machine does not have an external IP (one-to-one NAT)."
    }
    Write-Host "IP found: $vmIp"

    Write-Host "Obtaining an external IP address for Bastion..."
        $bastion = yc compute instance get --name bastion --format json | ConvertFrom-Json
        $bastionExternalIp = $bastion.network_interfaces[0].primary_v4_address.one_to_one_nat.address
        if (-not $bastionExternalIp) {
            Write-Error "Unable to determine external IP of Bastion"
            exit 1
        }

    # ---- Continue with setup ----

    $keyPath = "$env:USERPROFILE\.ssh\oslogin_key"
    if (-not (Test-Path $keyPath)) {
        throw "SSH key not found: $keyPath"
    }

    $localScript = "setup-k8s-worker.sh"
    if (-not (Test-Path $localScript)) {
        Write-Error "File '$localScript' not found in '$scriptsDir'."
        exit 1
    }

    Write-Host "Copying $localScript to $workerName : $vmIp ..."
    scp -i $keyPath "setup-k8s-worker.sh" "yc-user@${vmIp}:~/"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to copy script to remote machine."
        exit 1
    }

    function Invoke-Remote {
        param([string]$Commands)
        $sshArgs = @(
            '-i', $keyPath,
            '-t',   # Принудительное выделение псевдотерминала
            '-o', 'ServerAliveInterval=60',
            '-o', 'ServerAliveCountMax=20',
            "yc-user@${vmIp}",
            "export DEBIAN_FRONTEND=noninteractive; $Commands"
        )
        & ssh $sshArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Error executing commands on remote machine."
            exit 1
        }
    }

    Write-Host "=== Adding WORKER node ==="


    $token = Read-Host "Enter token: "
    $caHash =  Read-Host "Enter token-ca-cert-hash: "

    Write-Host $token
    Write-Host $caHash


    $joinCommands = @(
        "sudo bash ~/setup-k8s-worker.sh",
        "sudo kubeadm join ${bastionExternalIp}:6443 --token $token --discovery-token-ca-cert-hash $caHash "
    ) -join " && "

    #ssh -i $keyPath "yc-user@$vmIp" $initCommands
    #if ($LASTEXITCODE -ne 0) {
    #    throw "Error executing commands on remote machine."
    #}
    Invoke-Remote $joinCommands

    Write-Host "Worker node '$workerName' configuration completed."
}
catch {
    Write-Error "An error occurred: $_"
} 
finally {
    Set-Location $originalDir
    Write-Host "Returned to: $(Get-Location)"
}

Write-Host "Script finished."