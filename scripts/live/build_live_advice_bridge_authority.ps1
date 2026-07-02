param(
  [string]$AsOf = "2026-06-30 17:30:00",
  [string]$Quarter = "2026Q3",
  [string]$Symbols = "AMD,NVDA,PLTR,TSLA,SOFI",
  [string]$ContextSymbols = "SPY,QQQ,IWM,DIA,NVDA,TSLA,AMD,PLTR,SOFI,META,AAPL,KO,PEP,WMT,COST,XLF,JPM,BAC,XLE,CVX,XOM,TLT,IEF,GLD,SLV,VNQ,EFA,EEM,UVXY",
  [string]$CandidateFamilies = "ema_cross,ema_trend,bollinger_touch,bollinger_mid_reversion,rsi_mr,zret_mr,breakout,pullback_in_uptrend,vol_expansion_breakout,donchian_breakout_vol_expand,no_trade",
  [string]$StrategyGridPreset = "standard",
  [string]$Feed = "",
  [switch]$Refresh
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$rscript = "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe"
$args = @((Join-Path $PSScriptRoot "build_live_advice_bridge_authority.R"), "--as-of=$AsOf", "--quarter=$Quarter", "--symbols=$Symbols", "--context-symbols=$ContextSymbols", "--candidate-families=$CandidateFamilies", "--strategy-grid-preset=$StrategyGridPreset", "--refresh=$($Refresh.IsPresent)")
if ($Feed) { $args += "--feed=$Feed" }
& $rscript @args
