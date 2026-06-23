param(
    [Parameter(Mandatory=$true)]
    [string]$Command
)

$subId   = "65bf2554-8090-4538-9c38-8a6e9c5f6f22"
$rg      = "rg-archgen-dev"
$cluster = "aks-archgen-dev"

$token = (az account get-access-token --query accessToken -o tsv)
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
}

$body = @{ command = $Command; context = "" } | ConvertTo-Json

$runUrl = "https://management.azure.com/subscriptions/$subId/resourceGroups/$rg/providers/Microsoft.ContainerService/managedClusters/$cluster/runCommand?api-version=2024-01-01"

Write-Host "Submitting: $Command"
# Use Invoke-WebRequest to access response headers
$webResp = Invoke-WebRequest -Uri $runUrl -Method Post -Headers $headers -Body $body -ErrorAction Stop

$operationUrl = $webResp.Headers["Azure-AsyncOperation"]
if (-not $operationUrl) { $operationUrl = $webResp.Headers["Location"] }

Write-Host "Operation URL: $operationUrl"

$maxAttempts = 40
for ($i = 0; $i -lt $maxAttempts; $i++) {
    Start-Sleep -Seconds 3
    $pollResp = Invoke-RestMethod -Uri $operationUrl -Method Get -Headers $headers -ErrorAction Stop
    $status = $pollResp.status
    Write-Host "[$i] Status: $status"
    if ($status -eq "Succeeded") {
        Write-Host "`n=== LOGS ==="
        Write-Host $pollResp.properties.logs
        exit 0
    } elseif ($status -in @("Failed","Canceled","Cancelled")) {
        Write-Host "FAILED: $($pollResp | ConvertTo-Json -Depth 5)"
        exit 1
    }
}
Write-Host "Timed out"
exit 1
