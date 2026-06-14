
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
        $masterNum = Read-Host "Enter master number (1, 2, 3, ...)"
    } until ($masterNum -match '^\d+$' -and [int]$masterNum -ge 1)
    $masterName = "k8s-master-$masterNum"

    Write-Host "Target instance: $masterName"

    if (-not (Get-Command "yc" -ErrorAction SilentlyContinue)) {
        Write-Error "Yandex Cloud CLI (yc) is not installed or not in PATH."
        exit 1
    }

    #worker1adress
    $workerName = "k8s-worker-$masterNum"
    $shortWorker = "worker-$masterNum"

    $instanceJson3 = yc compute instance get --name $workerName --format json 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "YC compute instance get failed. Check that the YC CLI is configured."
    }
    $instance3 = $instanceJson3 | ConvertFrom-Json
    $vmIp3 = $instance3.network_interfaces[0].primary_v4_address.address
    if (-not $vmIp2) {
        throw "The vm-monitoring machine does not have an external IP (one-to-one NAT)."
    }


    # ---- IP retrieval with fallback ----
    Write-Host "Retrieving external IP for $masterName ..."

    # Try JSON method (as in other scripts)
    $externalIp = $null
    $instanceJson = yc compute instance get --name $masterName --format json 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "YC compute instance get failed. Check that the YC CLI is configured."
    }
    $instance = $instanceJson | ConvertFrom-Json
    $vmIp = $instance.network_interfaces[0].primary_v4_address.one_to_one_nat.address
    if (-not $vmIp) {
        throw "The vm-monitoring machine does not have an external IP (one-to-one NAT)."
    }
    Write-Host "IP found: $vmIp"

    $instanceJson2 = yc compute instance get --name bastion --format json 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "YC compute instance get failed. Check that the YC CLI is configured."
    }
    $instance2 = $instanceJson2 | ConvertFrom-Json
    $vmIp2 = $instance2.network_interfaces[0].primary_v4_address.one_to_one_nat.address
    if (-not $vmIp2) {
        throw "The vm-monitoring machine does not have an external IP (one-to-one NAT)."
    }


    # ---- Continue with setup ----

    $keyPath = "$env:USERPROFILE\.ssh\oslogin_key"
    if (-not (Test-Path $keyPath)) {
        throw "SSH key not found: $keyPath"
    }

    $localScript = "deployment.yaml"
    if (-not (Test-Path $localScript)) {
        Write-Error "File '$localScript' not found in '$scriptsDir'."
        exit 1
    }

    Write-Host "Copying $localScript to $masterName : $vmIp ..."
    scp -i $keyPath "deployment.yaml" "yc-user@${vmIp}:~/"
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

    function Invoke-Remote2 {
        param([string]$Commands)
        $sshArgs = @(
            '-i', $keyPath,
            '-t',   # Принудительное выделение псевдотерминала
            '-o', 'ServerAliveInterval=60',
            '-o', 'ServerAliveCountMax=20',
            "yc-user@${vmIp2}",
            "export DEBIAN_FRONTEND=noninteractive; $Commands"
        )
        & ssh $sshArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Error executing commands on remote machine."
            exit 1
        }
    }


    $github_login = Read-Host "Input GitHub login: "
    $project_name = Read-Host "Input project name: "
    $docker_password = Read-Host "Input deploy token: "
    
    $file = "deployment.yaml"
    (Get-Content $file) -replace 'image: ghcr\.io/.+?:latest', "image: ghcr.io/$github_login/$project_name`:latest" |
        Set-Content $file

    $initCommands = @(
                "kubectl create secret docker-registry ghcr-secret --docker-server=ghcr.io --docker-username=${github_login} --docker-password=$docker_password",
                "echo __________________kube_config_____________________",
                "kubectl get pods",
                "kubectl get svc",
                "echo _______________kube_config_end____________________",
                "kubectl apply -f ~/deployment.yaml",
                "cat ~/.kube/config"
                
            ) -join " && "

    $initCommands2 = @(
                "sudo apt-get update && sudo apt-get install -y haproxy

                sudo tee -a /etc/haproxy/haproxy.cfg << 'EOF'

                frontend app
                    bind *:30500
                    mode http
                    default_backend app-backend

                backend app-backend
                    mode http
                    server ${shortWorker} ${worker1adress}:30500 check
                EOF

                sudo systemctl restart haproxy"
                
            ) -join " && "

    Invoke-Remote $initCommands
    #Invoke-Remote2 $initCommands2

    Write-Host "Master node '$masterName' configuration completed."
}
catch {
    Write-Error "An error occurred: $_"
} 
finally {
    Set-Location $originalDir
    Write-Host "Returned to: $(Get-Location)"
}

Write-Host "Script finished."