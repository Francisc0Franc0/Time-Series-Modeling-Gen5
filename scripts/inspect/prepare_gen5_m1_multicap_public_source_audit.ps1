param(
    [Parameter(Mandatory = $true)]
    [string]$AsOfTimestamp,
    [switch]$Refresh
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$cacheDir = Join-Path $repoRoot ".cache\gen5_m1_multicap_public_source"
New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null

$sources = @(
    [pscustomobject]@{ Ticker = "IWL"; Url = "https://www.ishares.com/us/products/239721/ishares-russell-top-200-etf/latest-holdings.csv" },
    [pscustomobject]@{ Ticker = "IWR"; Url = "https://www.ishares.com/us/products/239718/ishares-russell-mid-cap-etf/latest-holdings.csv" },
    [pscustomobject]@{ Ticker = "IWM"; Url = "https://www.ishares.com/us/products/239710/ishares-russell-2000-etf/latest-holdings.csv" }
)

$manifest = foreach ($source in $sources) {
    $destination = Join-Path $cacheDir ($source.Ticker.ToLowerInvariant() + "_latest_holdings.csv")
    if ($Refresh -or -not (Test-Path -LiteralPath $destination)) {
        $partial = $destination + ".partial"
        Invoke-WebRequest -UseBasicParsing -Uri $source.Url -OutFile $partial
        Move-Item -Force -LiteralPath $partial -Destination $destination
    }
    $item = Get-Item -LiteralPath $destination
    [pscustomobject]@{
        fund_ticker = $source.Ticker
        request_url = $source.Url
        local_file = $item.FullName
        explicit_as_of_timestamp = $AsOfTimestamp
        retrieved_at_utc = $item.LastWriteTimeUtc.ToString("o")
        bytes = $item.Length
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $destination).Hash.ToLowerInvariant()
    }
}

$manifest | Export-Csv -NoTypeInformation -Encoding UTF8 -Path (Join-Path $cacheDir "acquisition_manifest.csv")
Write-Output "Prepared current iShares holdings in $cacheDir"
