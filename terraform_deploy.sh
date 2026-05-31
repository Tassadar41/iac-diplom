
Set-Location -Path "tf"
if (-not $?) { Write-Error "Ошибка: папка 'tf' не найдена"; exit 1 }
# Создайте статический IP и получите его ID
$ip = yc vpc address create --name bastion-static-ip --external-ipv4 zone=ru-central1-a --format json | ConvertFrom-Json | Select-Object -ExpandProperty id

# Замените address_id в файле
(Get-Content modules\bastion\main.tf) -replace 'address_id\s*=\s*".*"', "address_id = `"$ip`"" | Set-Content modules\bastion\main.tf

Write-Host "New IP ID: $ip" -ForegroundColor Green

# Применение terraform
terraform apply -auto-approve