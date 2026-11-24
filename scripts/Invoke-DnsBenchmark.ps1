#requires -Version 5.1
<#
.SYNOPSIS
  Compare explicit DNS resolvers from Windows without changing system DNS.
.DESCRIPTION
  Supports warm lookups, varied real domains, unique wildcard hostnames,
  unique unlikely-to-exist names, and an Epic regional test hostname.
  CSV output contains the individual measured queries. No router secrets are read.
.EXAMPLE
  .\scripts\Invoke-DnsBenchmark.ps1 -Mode Warm -Resolvers Huawei,Quad9,Cloudflare,Google
.EXAMPLE
  .\scripts\Invoke-DnsBenchmark.ps1 -Mode RealDomains -Resolvers Huawei,Quad9
.EXAMPLE
  .\scripts\Invoke-DnsBenchmark.ps1 -Mode FreshLabels -Resolvers Huawei,Quad9 -Iterations 100
#>
[CmdletBinding()]
param(
    [ValidateSet('Warm','RealDomains','FreshLabels','Negative','Fortnite')]
    [string]$Mode = 'Warm',
    [ValidateSet('Huawei','Quad9','Cloudflare','Google')]
    [string[]]$Resolvers = @('Huawei','Quad9','Cloudflare'),
    [string]$HuaweiDns = '192.168.100.1',
    [ValidateRange(0,2000)]
    [int]$Iterations = 0,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\runs')
)

$ErrorActionPreference = 'Stop'
$serverMap = @{
    Huawei     = $HuaweiDns
    Quad9      = '9.9.9.9'
    Cloudflare = '1.1.1.1'
    Google     = '8.8.8.8'
}
$resolvedNames = @($Resolvers | Select-Object -Unique)
if ($resolvedNames.Count -lt 2) { throw 'Specify at least two resolvers.' }

$domains = @(
    'google.com','github.com','microsoft.com','wikipedia.org','cloudflare.com',
    'amazon.com','discord.com','twitch.tv','youtube.com','reddit.com',
    'facebook.com','instagram.com','apple.com','netflix.com','spotify.com',
    'bing.com','nvidia.com','steamcommunity.com','epicgames.com','openai.com'
)
$realDomains = @(
    'kernel.org','gentoo.org','freebsd.org','nixos.org','archlinux.org',
    'debian.org','llvm.org','sqlite.org','ffmpeg.org','qemu.org','winehq.org',
    'curl.se','imagemagick.org','darktable.org','krita.org','inkscape.org',
    'godotengine.org','blender.org','kicad.org','wireshark.org','keepassxc.org',
    'freedesktop.org','gnu.org','git-scm.com','neovim.io','vim.org',
    'rust-lang.org','openstreetmap.org','torproject.org','matrix.org'
)

if ($Iterations -eq 0) {
    $Iterations = switch ($Mode) {
        'Warm'         { 5 }   # rounds x 20 domains = 100 queries per resolver
        'RealDomains'  { 1 }   # 30 domains x 1 = 30 queries per resolver
        'FreshLabels'  { 100 }
        'Negative'     { 50 }
        'Fortnite'     { 20 }
    }
}

function Get-Percentile {
    param([double[]]$Sorted, [double]$Probability)
    if ($Sorted.Count -eq 0) { return $null }
    $idx = [int]([math]::Ceiling($Sorted.Count * $Probability) - 1)
    return [math]::Round($Sorted[$idx], 2)
}

function Invoke-Query {
    param(
        [string]$ResolverName,
        [string]$Domain,
        [string]$ExpectedIp = '',
        [string]$ExpectedKind = 'Positive',
        [int]$Round = 0
    )
    $address = $serverMap[$ResolverName]
    $outcome = 'DNS_ERROR'
    $responseIPs = ''
    $errorCode = ''
    $clock = [Diagnostics.Stopwatch]::StartNew()
    try {
        $answer = @(Resolve-DnsName -Name $Domain -Server $address -Type A -DnsOnly -NoHostsFile -ErrorAction Stop)
        $ips = @($answer | Where-Object { $_.Type -eq 'A' -and $_.IPAddress } |
            ForEach-Object { $_.IPAddress } | Sort-Object -Unique)
        $responseIPs = $ips -join ';'
        if ($ips.Count -eq 0) { $outcome = 'NO_A_RECORD' }
        elseif ($ExpectedIp -and ($ips -notcontains $ExpectedIp)) { $outcome = 'UNEXPECTED_IP' }
        else { $outcome = 'A_RECORD' }
    }
    catch {
        $errorCode = [string]$_.FullyQualifiedErrorId
        $message = [string]$_.Exception.Message
        # Resolve-DnsName surfaces NXDOMAIN as a terminating exception.
        # Never classify all exceptions as NXDOMAIN: timeouts and SERVFAIL differ.
        if (($errorCode + ' ' + $message) -match '(?i)DNS_ERROR_RCODE_NAME_ERROR|NXDOMAIN|DNS name does not exist|name does not exist|error code 9003|\b9003\b') {
            $outcome = 'NXDOMAIN'
        }
        else { $outcome = 'DNS_ERROR' }
    }
    finally { $clock.Stop() }

    $expectedOK = if ($ExpectedKind -eq 'Negative') {
        $outcome -eq 'NXDOMAIN'
    } else {
        $outcome -eq 'A_RECORD'
    }
    [pscustomobject]@{
        UtcTime      = [datetime]::UtcNow.ToString('o')
        Mode         = $Mode
        Round        = $Round
        Resolver     = $ResolverName
        Server       = $address
        Domain       = $Domain
        Milliseconds = [math]::Round($clock.Elapsed.TotalMilliseconds, 4)
        Outcome      = $outcome
        ExpectedOK   = $expectedOK
        ARecords     = $responseIPs
        ErrorCode    = $errorCode
    }
}

$results = [Collections.Generic.List[object]]::new()
Write-Host "Mode: $Mode | DNS: $($resolvedNames -join ', ') | iterations: $Iterations" -ForegroundColor Cyan

switch ($Mode) {
    'Warm' {
        for ($round=1; $round -le $Iterations; $round++) {
            foreach ($domain in ($domains | Get-Random -Count $domains.Count)) {
                foreach ($resolver in ($resolvedNames | Get-Random -Count $resolvedNames.Count)) {
                    $results.Add((Invoke-Query -ResolverName $resolver -Domain $domain -Round $round))
                }
            }
            Write-Host "Round $round/$Iterations complete"
        }
    }
    'RealDomains' {
        for ($round=1; $round -le $Iterations; $round++) {
            foreach ($domain in ($realDomains | Get-Random -Count $realDomains.Count)) {
                foreach ($resolver in ($resolvedNames | Get-Random -Count $resolvedNames.Count)) {
                    $results.Add((Invoke-Query -ResolverName $resolver -Domain $domain -Round $round))
                }
            }
            Write-Host "Round $round/$Iterations complete"
        }
    }
    'Fortnite' {
        for ($round=1; $round -le $Iterations; $round++) {
            foreach ($resolver in ($resolvedNames | Get-Random -Count $resolvedNames.Count)) {
                $results.Add((Invoke-Query -ResolverName $resolver -Domain 'ping-sao.ds.on.epicgames.com' -Round $round))
            }
            if ($round % 5 -eq 0) { Write-Host "Round $round/$Iterations complete" }
        }
    }
    'FreshLabels' {
        Write-Warning 'Fresh labels avoid exact-name cache reuse; upstream zone and delegation caches remain warm.'
        for ($round=1; $round -le $Iterations; $round++) {
            $zone = if (($round % 2) -eq 0) { 'nip.io' } else { 'sslip.io' }
            foreach ($resolver in ($resolvedNames | Get-Random -Count $resolvedNames.Count)) {
                $nonce = [guid]::NewGuid().ToString('N')
                $domain = "r$nonce.8.8.8.8.$zone"
                $results.Add((Invoke-Query -ResolverName $resolver -Domain $domain -ExpectedIp '8.8.8.8' -Round $round))
            }
            if ($round % 20 -eq 0) { Write-Host "Round $round/$Iterations complete" }
        }
    }
    'Negative' {
        Write-Warning 'Negative tests measure nonexistent names, not ordinary website resolution. NXDOMAIN detection depends on localized error messages.'
        for ($round=1; $round -le $Iterations; $round++) {
            $domain = "z$([guid]::NewGuid().ToString('N')).com"
            foreach ($resolver in ($resolvedNames | Get-Random -Count $resolvedNames.Count)) {
                $results.Add((Invoke-Query -ResolverName $resolver -Domain $domain -ExpectedKind Negative -Round $round))
            }
            if ($round % 10 -eq 0) { Write-Host "Round $round/$Iterations complete" }
        }
    }
}

$summary = foreach ($resolver in $resolvedNames) {
    $all = @($results | Where-Object { $_.Resolver -eq $resolver })
    # In negative mode, include only confirmed NXDOMAIN replies in latency statistics.
    $good = @($all | Where-Object { $_.ExpectedOK })
    $times = [double[]]@($good | ForEach-Object { $_.Milliseconds } | Sort-Object)
    $measure = if ($times.Count) { $times | Measure-Object -Average } else { $null }
    [pscustomobject]@{
        Mode      = $Mode
        Resolver  = $resolver
        Server    = $serverMap[$resolver]
        Valid     = "$($good.Count)/$($all.Count)"
        AverageMs = if ($times.Count) { [math]::Round($measure.Average,2) } else { $null }
        MedianMs  = Get-Percentile $times 0.50
        P95Ms     = Get-Percentile $times 0.95
        P99Ms     = Get-Percentile $times 0.99
        MaxMs     = if ($times.Count) { [math]::Round($times[-1],2) } else { $null }
    }
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$rawPath = Join-Path $OutputDirectory "dns-$($Mode.ToLower())-$stamp-raw.csv"
$summaryPath = Join-Path $OutputDirectory "dns-$($Mode.ToLower())-$stamp-summary.csv"
$results | Export-Csv -Path $rawPath -NoTypeInformation -Encoding UTF8
$summary | Export-Csv -Path $summaryPath -NoTypeInformation -Encoding UTF8
Write-Host "`n=== $Mode ===" -ForegroundColor Green
$summary | Sort-Object MedianMs | Format-Table -AutoSize
Write-Host "Raw queries: $rawPath"
Write-Host "Summary: $summaryPath"
if ($Mode -eq 'Fortnite') {
    Write-Host "`nA-record sets observed (order may vary):" -ForegroundColor Cyan
    foreach ($resolver in $resolvedNames) {
        $ips = @($results | Where-Object { $_.Resolver -eq $resolver -and $_.ARecords } |
            ForEach-Object { $_.ARecords -split ';' } | Sort-Object -Unique)
        Write-Host "$resolver : $($ips -join ', ')"
    }
}
