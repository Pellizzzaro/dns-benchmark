#requires -Version 5.1
<#
.SYNOPSIS
  ICMP latency test of known regional endpoints; no game installation required.
.DESCRIPTION
  Does not simulate matchmaking or measure game UDP packet delivery.
.EXAMPLE
  .\scripts\Test-GameEndpoints.ps1 -TargetSet Fortnite -Count 30
#>
[CmdletBinding()]
param(
    [ValidateSet('Fortnite','Reference','All')]
    [string]$TargetSet = 'Fortnite',
    [ValidateRange(1,1000)]
    [int]$Count = 30,
    [ValidateRange(100,10000)]
    [int]$TimeoutMs = 2000,
    [ValidateRange(0,10000)]
    [int]$DelayMs = 250,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\runs')
)
$targets = [ordered]@{}
if ($TargetSet -in @('Fortnite','All')) {
    # Observed A records of Epic's Sao Paulo test endpoint on 2026-11-24.
    # These are diagnostic endpoints, NOT necessarily live match servers.
    $targets['Fortnite-118'] = '15.228.25.118'
    $targets['Fortnite-138'] = '15.228.25.138'
    $targets['Fortnite-140'] = '15.228.25.140'
    $targets['Fortnite-156'] = '15.228.25.156'
}
if ($TargetSet -in @('Reference','All')) {
    $targets['Cloudflare'] = '1.1.1.1'
    $targets['Quad9'] = '9.9.9.9'
}
function Pct {
    param([double[]]$Sorted,[double]$Probability)
    if (-not $Sorted.Count) { return $null }
    $idx = [int]([math]::Ceiling($Sorted.Count * $Probability) - 1)
    [math]::Round($Sorted[$idx],2)
}
$records = [Collections.Generic.List[object]]::new()
$ping = New-Object System.Net.NetworkInformation.Ping
try {
    foreach ($name in @($targets.Keys)) {
        Write-Host "Testing $name : $($targets[$name]) ($Count ICMP echoes)" -ForegroundColor Cyan
        for ($i = 1; $i -le $Count; $i++) {
            $status = 'ERROR'
            $elapsed = $null
            try {
                $r = $ping.Send($targets[$name], $TimeoutMs)
                $status = [string]$r.Status
                if ($r.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                    $elapsed = [double]$r.RoundtripTime
                }
            } catch { $status = [string]$_.Exception.GetType().Name }
            $records.Add([pscustomobject]@{
                UtcTime = [datetime]::UtcNow.ToString('o')
                Endpoint = $name
                IP = $targets[$name]
                Sequence = $i
                Status = $status
                Milliseconds = $elapsed
            })
            if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
        }
    }
} finally { $ping.Dispose() }
$summary = foreach ($name in @($targets.Keys)) {
    $all = @($records | Where-Object { $_.Endpoint -eq $name })
    $good = @($all | Where-Object { $_.Status -eq 'Success' })
    $sorted = [double[]]@($good | ForEach-Object { $_.Milliseconds } | Sort-Object)
    [pscustomobject]@{
        Endpoint = $name
        IP = $targets[$name]
        Received = "$($good.Count)/$($all.Count)"
        MinMs = if ($sorted.Count) { $sorted[0] } else { $null }
        AverageMs = if ($sorted.Count) { [math]::Round(($sorted | Measure-Object -Average).Average,2) } else { $null }
        MedianMs = Pct $sorted 0.50
        P95Ms = Pct $sorted 0.95
        MaxMs = if ($sorted.Count) { $sorted[-1] } else { $null }
    }
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$raw = Join-Path $OutputDirectory "icmp-$TargetSet-$stamp-raw.csv"
$summ = Join-Path $OutputDirectory "icmp-$TargetSet-$stamp-summary.csv"
$records | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $raw
$summary | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $summ
$summary | Format-Table -AutoSize
Write-Host "Raw: $raw`nSummary: $summ"
Write-Warning 'ICMP endpoints may not respond even when gaming services work. This does not test UDP gameplay latency.'
