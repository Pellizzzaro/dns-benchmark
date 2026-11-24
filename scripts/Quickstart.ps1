#requires -Version 5.1
# Runs a modest, non-invasive comparison. Explicit queries do not change Windows DNS settings.
& "$PSScriptRoot\Invoke-DnsBenchmark.ps1" -Mode Warm -Resolvers Huawei,Quad9,Cloudflare,Google
& "$PSScriptRoot\Invoke-DnsBenchmark.ps1" -Mode RealDomains -Resolvers Huawei,Quad9,Cloudflare
& "$PSScriptRoot\Invoke-DnsBenchmark.ps1" -Mode Fortnite -Resolvers Huawei,Quad9,Cloudflare
Write-Host 'Finished. Individual result CSV files are in the runs folder.' -ForegroundColor Green
