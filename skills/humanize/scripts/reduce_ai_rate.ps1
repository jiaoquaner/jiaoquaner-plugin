#Requires -Version 5.1
<#
焦圈儿「降 AI 率」接口的一次性调用脚本（Windows PowerShell 版）。

  POST https://api-server.jiaoquaner.com/api/v1/agent/reduce-ai-rate

与同目录 reduce_ai_rate.sh 契约完全一致，供没有 bash 的 Windows 环境使用。

用法：
  .\reduce_ai_rate.ps1 -File draft.md              从文件读原文
  .\reduce_ai_rate.ps1 -Text "这是一段原文"          直接传文本
  Get-Content draft.md -Raw | .\reduce_ai_rate.ps1  从 stdin 读原文
  .\reduce_ai_rate.ps1 -File draft.md -Out out.md   同时把正文写入文件
  .\reduce_ai_rate.ps1 -File draft.md -Json         stdout 输出完整响应 JSON

  执行策略拦截时：powershell -ExecutionPolicy Bypass -File .\reduce_ai_rate.ps1 -File draft.md

输出约定：
  stdout  成功时 = 改写后的完整正文（-Json 时为完整响应 JSON）
  stderr  content_id / content_chat_id 等元信息，以及错误说明
  退出码  0 成功 | 2 接口业务错误(code!=0) | 3 网络/HTTP 失败
          4 用法错误（缺 key、空输入等） | 5 环境缺依赖

计费：每次成功调用都真实扣除焦耳，失败不扣费。脚本不做任何自动重试。
#>
[CmdletBinding()]
param(
  [Alias('f')][string]$File,
  [Alias('t')][string]$Text,
  [Alias('o')][string]$Out,
  [switch]$Json,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'

function Write-Err([string]$m) { [Console]::Error.WriteLine($m) }
function Die([string]$m, [int]$code = 4) { Write-Err "error: $m"; exit $code }
function Show-Usage {
  @'
焦圈儿「降 AI 率」接口调用脚本（PowerShell 版）

  .\reduce_ai_rate.ps1 -File draft.md              从文件读原文
  .\reduce_ai_rate.ps1 -Text "这是一段原文"          直接传文本
  Get-Content draft.md -Raw | .\reduce_ai_rate.ps1  从 stdin 读原文
  .\reduce_ai_rate.ps1 -File draft.md -Out out.md   同时把正文写入文件
  .\reduce_ai_rate.ps1 -File draft.md -Json         stdout 输出完整响应 JSON

stdout = 改写后正文；stderr = content_id 等元信息与错误说明
退出码 0 成功 | 2 业务错误 | 3 网络失败 | 4 用法错误 | 5 缺依赖
API Key 从环境变量 JIAOQUANER_API_KEY 读取。
'@
}

if ($Help) { Show-Usage; exit 0 }

# ---- 1. API Key ------------------------------------------------------------
$apiKey = $env:JIAOQUANER_API_KEY
if (-not $apiKey) { $apiKey = $env:jiaoquaner_api_key }
if (-not $apiKey) {
  Die '未配置 API Key：请先 $env:JIAOQUANER_API_KEY = "sk-xxxxxx"'
}

$apiBase = $env:JIAOQUANER_API_BASE
if (-not $apiBase) { $apiBase = 'https://api-server.jiaoquaner.com' }
$url = ($apiBase.TrimEnd('/')) + '/api/v1/agent/reduce-ai-rate'

# ---- 2. 读入原文（统一按 UTF-8，不做任何转义处理）---------------------------
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

if ($File) {
  if (-not (Test-Path -LiteralPath $File -PathType Leaf)) { Die "文件不存在: $File" }
  $full = (Resolve-Path -LiteralPath $File).ProviderPath
  $inputText = [System.IO.File]::ReadAllText($full, $utf8NoBom)
} elseif ($PSBoundParameters.ContainsKey('Text')) {
  $inputText = $Text
} elseif ([Console]::IsInputRedirected) {
  $inputText = [Console]::In.ReadToEnd()
} else {
  Show-Usage | Write-Err
  Die '没有拿到待处理文本：用 -File 文件、-Text 文本 或 stdin 传入'
}

if ([string]::IsNullOrWhiteSpace($inputText)) {
  Die 'input 为空：接口要求 input 必填、不可为空'
}

# ---- 3. 构造请求体（ConvertTo-Json 负责转义，绝不手拼字符串）----------------
$bodyJson  = @{ input = $inputText } | ConvertTo-Json -Depth 3 -Compress
$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($bodyJson)

# ---- 4. 发请求（不重试；key 不回显）----------------------------------------
try {
  [Net.ServicePointManager]::SecurityProtocol =
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }

$raw = $null
try {
  $resp = Invoke-WebRequest -Uri $url -Method Post `
    -Headers @{ Authorization = "Bearer $apiKey" } `
    -ContentType 'application/json; charset=utf-8' `
    -Body $bodyBytes -UseBasicParsing
  try   { $raw = [System.Text.Encoding]::UTF8.GetString($resp.RawContentStream.ToArray()) }
  catch { $raw = [string]$resp.Content }
} catch {
  # 4xx/5xx 也可能带业务 JSON（如 code=11501），先把响应体捞出来按 code 解析
  if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
    $raw = $_.ErrorDetails.Message
  } elseif ($_.Exception.PSObject.Properties['Response'] -and $_.Exception.Response) {
    try {
      $stream = $_.Exception.Response.GetResponseStream()
      $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
      $raw = $reader.ReadToEnd()
    } catch { }
  }
  if (-not $raw) {
    $msg = $_.Exception.Message -replace 'Bearer\s+\S+', 'Bearer ***'
    Die "请求失败（$msg），未扣费，可稍后手动重试" 3
  }
}

# ---- 5. 解析响应 -----------------------------------------------------------
$obj = $null
try { $obj = $raw | ConvertFrom-Json } catch { $obj = $null }

if (-not $obj -or $null -eq $obj.PSObject.Properties['code']) {
  Write-Err 'error: 响应不是预期的 JSON，原始响应：'
  Write-Err ([string]$raw).Substring(0, [Math]::Min(2000, ([string]$raw).Length))
  exit 3
}

$code = [string]$obj.code
if ($code -ne '0') {
  $msg = ''
  if ($obj.PSObject.Properties['msg'])     { $msg = [string]$obj.msg }
  elseif ($obj.PSObject.Properties['message']) { $msg = [string]$obj.message }
  $hint = switch ($code) {
    '10401' { '输入含违规内容：修改原文后再试（未扣费）' }
    '10706' { '焦耳余额不足：请充值或检查余额（未扣费）' }
    '11501' { 'API Key 无效：检查 JIAOQUANER_API_KEY 是否正确、是否携带' }
    '11502' { 'API Key 已禁用：更换可用 key' }
    '11503' { 'API Key 已过期：更换 key' }
    '500'   { '服务内部错误（不扣费）：稍后重试；持续失败请反馈后端' }
    default { '未知错误码，把 code 与 msg 反馈给焦圈儿' }
  }
  Write-Err "error: 接口返回 code=$code msg=$msg"
  Write-Err "hint: $hint"
  exit 2
}

$data = $obj.data
$output = if ($data -and $data.PSObject.Properties['output']) { [string]$data.output } else { '' }
if ([string]::IsNullOrEmpty($output)) {
  Write-Err 'error: code=0 但 data.output 为空，原始响应：'
  Write-Err ([string]$raw).Substring(0, [Math]::Min(2000, ([string]$raw).Length))
  exit 2
}

if ($data.PSObject.Properties['content_id'] -and $data.content_id) {
  Write-Err ("content_id=" + $data.content_id)
}
if ($data.PSObject.Properties['content_chat_id'] -and $data.content_chat_id) {
  Write-Err ("content_chat_id=" + $data.content_chat_id)
}

if ($Out) {
  [System.IO.File]::WriteAllText($Out, $output + "`n", $utf8NoBom)
  Write-Err "saved=$Out"
}

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
if ($Json) { [Console]::Out.Write($raw + "`n") } else { [Console]::Out.Write($output + "`n") }
exit 0
