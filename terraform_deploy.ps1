# Функция для запроса подтверждения
function Confirm-StaticAddress {
    while ($true) {
        $response = Read-Host "You already create static ip? (y/n)"
        switch ($response.ToLower()) {
            'y' { return $true }
            'n' { return $false }
            default { Write-Host "Please, answer y or n." -ForegroundColor Yellow }
        }
    }
}
$ProjectRoot = Get-Location
try{
    Set-Location -Path "tf"
    if (-not $?) {
        Write-Error "Error folder0 'tf' not found"
        exit 1
    }

    if (Confirm-StaticAddress) {
        terraform apply -auto-approve
    }
    else {

        
        # Создайте статический IP и получите его ID
        Write-Host "Creating static ip adress..." -ForegroundColor Cyan
        $ipResult = yc vpc address create --name bastion-static-ip --external-ipv4 zone=ru-central1-a --format json | ConvertFrom-Json
        $ip = $ipResult.id

        # Замените address_id в файле
        $filePath = "modules\bastion\main.tf"
        if (Test-Path $filePath) {
            $content = Get-Content $filePath -Raw
            $newContent = $content -replace 'address_id\s*=\s*".*"', "address_id = `"$ip`""
            Set-Content -Path $filePath -Value $newContent
            
            Write-Host "New IP ID: $ip" -ForegroundColor Green
            
            # Применение terraform
            terraform apply -auto-approve
        }
        else {
            Write-Error "Error: file '$filePath' not found"
            exit 1
        }
    }
}
finally{
    #возвращаемся в корень проекта
    Set-Location -Path $ProjectRoot
    Write-Host "Returned to the root project folder: $ProjectRoot"
}
