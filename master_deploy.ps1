# setup-k8s-master.ps1

$originalDir = Get-Location

try {
    $scriptsDir = Join-Path $originalDir "setup-scripts"
    if (-not (Test-Path $scriptsDir)) {
        Write-Error "Folder 'setup-scripts' not found in the current directory."
        exit 1
    }
    Set-Location $scriptsDir
    Write-Host "Changed directory to: $(Get-Location)"

    do {
        $masterNum = Read-Host "Enter the master number (1, 2, 3, ...)"
    } until ($masterNum -match '^\d+$' -and [int]$masterNum -ge 1)
    $masterName = "k8s-master-$masterNum"
    Write-Host "Target instance: $masterName"

    if (-not (Get-Command "yc" -ErrorAction SilentlyContinue)) {
        Write-Error "Yandex Cloud CLI (yc) is not installed or not in PATH."
        exit 1
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

    # If JSON didn't give external IP, try text method
    if (-not $externalIp) {
        $ycOutput = yc compute instance get $masterName --format text 2>&1
        if ($LASTEXITCODE -eq 0) {
            foreach ($line in $ycOutput -split "`r`n") {
                if ($line -match 'one-to-one-nat:\s*(\d+\.\d+\.\d+\.\d+)') {
                    $externalIp = $matches[1]
                    break
                }
            }
        }
    }

    Write-Host "Using IP: $externalIp"

    Write-Host "Obtaining an external IP address for Bastion..."
        $bastion = yc compute instance get --name bastion --format json | ConvertFrom-Json
        $bastionExternalIp = $bastion.network_interfaces[0].primary_v4_address.one_to_one_nat.address
        if (-not $bastionExternalIp) {
            Write-Error "Unable to determine external IP of Bastion"
            exit 1
        }

    # ---- Continue with setup ----
    do {
        $isFirst = Read-Host "Is this the first master node? (y/n)"
    } until ($isFirst -match '^[yn]$')
    $isFirstMaster = ($isFirst -eq 'y')

    $keyPath = "$env:USERPROFILE\.ssh\oslogin_key"
    if (-not (Test-Path $keyPath)) {
        throw "SSH key not found: $keyPath"
    }

    $localScript = "setup-k8s-master.sh"
    if (-not (Test-Path $localScript)) {
        Write-Error "File '$localScript' not found in '$scriptsDir'."
        exit 1
    }

    Write-Host "Copying $localScript to $masterName : $vmIp ..."
    scp -i $keyPath "setup-k8s-master.sh" "yc-user@${vmIp}:~/"
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

$clusterInfoFile = Join-Path $originalDir "cluster-info.json"

    if ($isFirstMaster) {
        Write-Host "=== Setting up the FIRST master node ==="

        $initCommands = @(
            #"sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg",
            "sudo bash ~/setup-k8s-master.sh",
            "if [ ! -f /etc/kubernetes/admin.conf ]; then sudo kubeadm init --control-plane-endpoint=${bastionExternalIp}:6443 --pod-network-cidr=10.244.0.0/16 --upload-certs; fi",
            "mkdir -p ~/.kube",
            "sudo cp -f /etc/kubernetes/admin.conf ~/.kube/config 2>/dev/null || true",
            "sudo chown yc-user:yc-user ~/.kube/config 2>/dev/null || true",
            "echo 'Waiting for Kubernetes API (max 2 minutes)...'",
            "for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24; do kubectl --kubeconfig ~/.kube/config get nodes &>/dev/null && break; echo -n '.'; sleep 5; done",
            "kubectl --kubeconfig ~/.kube/config get nodes || (echo 'API still not ready'; exit 1)",
            "kubectl --kubeconfig ~/.kube/config apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml",
            "kubectl --kubeconfig ~/.kube/config get nodes",
            "command -v helm >/dev/null || (curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | sudo bash)",
            "helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true",
            "helm repo update"
            
        ) -join " && "
        
        # команда на удаление в случае ошибки
        
        $initCommandsPart2 = @(
            "echo part_2_launch ",
            #"kubectl --kubeconfig ~/.kube/config taint node $(hostname) node-role.kubernetes.io/control-plane:NoSchedule- 2>/dev/null || true",
            "kubectl --kubeconfig ~/.kube/config taint node master-1 node-role.kubernetes.io/control-plane:NoSchedule- 2>/dev/null || true",
            "helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace",
            "kubectl --kubeconfig ~/.kube/config wait --for=condition=ready pod -l app=kube-prometheus-stack-prometheus -n monitoring --timeout=10m 2>/dev/null || true"
            "kubectl patch svc kube-prometheus-kube-prome-prometheus -n monitoring -p '{""spec"":{""type"":""NodePort""}}' || true",
            "kubectl get svc -n monitoring -l app=kube-prometheus-stack-prometheus"
        ) -join " && "
        #ssh -i $keyPath "yc-user@$vmIp" $initCommands
        #if ($LASTEXITCODE -ne 0) {
        #    throw "Error executing commands on remote machine."
        #}
        Invoke-Remote $initCommands
        Invoke-Remote $initCommandsPart2

        # Генерация и сохранение join-токенов и сертификатов
        #Write-Host "Generating join tokens for additional masters..."
        #$joinCmd = ssh -i $sshKey "yc-user@${bastionExternalIp}" "sudo kubeadm token create --print-join-command 2>/dev/null"
        #$certKey = ssh -i $sshKey "yc-user@${bastionExternalIp}" "sudo kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -1"

        #if ($joinCmd -and $certKey) {
            #if ($joinCmd -match '--token (\S+).*--discovery-token-ca-cert-hash (\S+)') {
                #$token = $matches[1]
                #$caHash = $matches[2]
                #$clusterInfo = @{
                    #EndpointIp     = $bastionExternalIp
                    #Token          = $token
                    #CaCertHash     = $caHash
                    #CertificateKey = $certKey.Trim()
                #}
                #$clusterInfo | ConvertTo-Json | Set-Content -Path $clusterInfoFile -Encoding UTF8
                #Write-Host "Cluster join information saved to: $clusterInfoFile"
            #} else {
                #Write-Warning "Could not parse join command. You may need to manually copy the tokens."
            #}
        #} else {
            #Write-Warning "Failed to retrieve join tokens. Make sure 'kubeadm init' completed successfully."
        #}

    } else {
        Write-Host "=== Adding an additional CONTROL-PLANE node ==="


        $token = Read-Host "Enter token: "
        $caHash =  Read-Host "Enter token-ca-cert-hash: "
        $certKey = Read-Host "Enter certificate-key: "

        Write-Host $token
        Write-Host $caHash
        Write-Host $certKey

        $joinCommands = @(
            "sudo bash ~/setup-k8s-master.sh",
            "sudo kubeadm join ${bastionExternalIp}:6443 --token $token --discovery-token-ca-cert-hash $caHash --control-plane --certificate-key $certKey"
        ) -join " && "

        #ssh -i $keyPath "yc-user@$vmIp" $initCommands
        #if ($LASTEXITCODE -ne 0) {
        #    throw "Error executing commands on remote machine."
        #}
        Invoke-Remote $joinCommands
    }

    Write-Host "Master node '$masterName' configuration completed."

} catch {
    Write-Error "An error occurred: $_"
} finally {
    Set-Location $originalDir
    Write-Host "Returned to: $(Get-Location)"
}

Write-Host "Script finished."