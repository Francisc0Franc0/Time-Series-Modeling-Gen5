param(
  [string]$AsOf = "2026-06-30 17:30:00",
  [string]$Quarter = "2026Q3",
  [string]$Symbols = "AMD,NVDA,PLTR,TSLA,SOFI",
  [string]$ContextSymbols = "SPY,QQQ,IWM,DIA,NVDA,TSLA,AMD,PLTR,SOFI,META,AAPL,KO,PEP,WMT,COST,XLF,JPM,BAC,XLE,CVX,XOM,TLT,IEF,GLD,SLV,VNQ,EFA,EEM,UVXY",
  [string]$Feed = "",
  [switch]$Refresh
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$rscript = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"
$args = @((Join-Path $PSScriptRoot "build_live_advice_bridge_authority.R"), "--as-of=$AsOf", "--quarter=$Quarter", "--symbols=$Symbols", "--context-symbols=$ContextSymbols", "--refresh=$($Refresh.IsPresent)")
if ($Feed) { $args += "--feed=$Feed" }
& $rscript @args
