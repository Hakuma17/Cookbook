param(
  [Parameter(HelpMessage='เช่น http://10.0.2.2/cookbookapp/ หรือ http://localhost/cookbookapp/')]
  [string]$BaseUrl = 'http://10.0.2.2/cookbookapp/',
  [Parameter(HelpMessage='อีเมลสำหรับทดสอบ (ตัวเลือก)')]
  [string]$Email,
  [Parameter(HelpMessage='รหัสผ่านสำหรับทดสอบ (ตัวเลือก)')]
  [string]$Password,
  [switch]$RunAuthTests,
  [switch]$RunWriteTests,
  [int]$Limit = 5
)

# ทำให้แน่ใจว่า BaseUrl ลงท้ายด้วย /
if (-not $BaseUrl.EndsWith('/')) { $BaseUrl += '/' }

$ErrorActionPreference = 'Stop'
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Pass($msg) { Write-Host "  ✔ $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "  ✖ $msg" -ForegroundColor Red }

function Invoke-Api {
  param(
    [string]$Path,
    [hashtable]$Query,
    [ValidateSet('GET','POST')]
    [string]$Method = 'GET',
    [hashtable]$Body,
    [switch]$Public
  )
  $url = $BaseUrl + $Path
  if ($Query) {
    $qs = ($Query.GetEnumerator() | ForEach-Object { "{0}={1}" -f [System.Uri]::EscapeDataString($_.Key), [System.Uri]::EscapeDataString( ($_.Value | Out-String).Trim() ) }) -join '&'
    if ($qs) { $url = "$url`?$qs" }
  }
  try {
    if ($Method -eq 'POST') {
      $headers = @{ 'Content-Type' = 'application/x-www-form-urlencoded' }
      if ($Public) { } # ไม่ต้องส่งคุกกี้
      $resp = Invoke-WebRequest -Uri $url -Method Post -WebSession $session -Headers $headers -Body $Body -UseBasicParsing
    } else {
      $resp = Invoke-WebRequest -Uri $url -Method Get -WebSession $session -UseBasicParsing
    }
  } catch {
    $we = $_.Exception
    if ($we.Response -and $we.Response -is [System.Net.HttpWebResponse]) {
      $r = $we.Response
      $sr = New-Object System.IO.StreamReader($r.GetResponseStream())
      $content = $sr.ReadToEnd()
      return [pscustomobject]@{ StatusCode=[int]$r.StatusCode; Content=$content; Json=$null; Ok=$false; Url=$url }
    }
    throw
  }
  $json = $null
  try { if ($resp.Content) { $json = $resp.Content | ConvertFrom-Json -ErrorAction Stop } } catch { }
  return [pscustomobject]@{ StatusCode=[int]$resp.StatusCode; Content=$resp.Content; Json=$json; Ok=($resp.StatusCode -lt 400); Url=$url }
}

function Assert-True($cond, $msgOk, $msgFail) {
  if ($cond) { Write-Pass $msgOk } else { Write-Fail $msgFail }
}

# ─────────────────────────────────────────────────────────────────
# 1) Public endpoints
# ─────────────────────────────────────────────────────────────────
Write-Step 'Public: ingredients & groups'
$ing = Invoke-Api -Path 'get_ingredients.php'
Assert-True ($ing.Ok -and $ing.Json) 'GET get_ingredients.php' "GET get_ingredients.php • HTTP $($ing.StatusCode)"

$groups = Invoke-Api -Path 'get_ingredient_groups.php'
if (-not $groups.Ok) {
  Write-Host '  • get_ingredient_groups.php ไม่พร้อม ใช้ fallback ผ่าน get_ingredients.php?grouped=1 แทนในแอป' -ForegroundColor Yellow
}

Write-Step 'Public: recipe feeds (popular/new)'
$pop = Invoke-Api -Path 'get_popular_recipes.php'
Assert-True ($pop.Ok -and $pop.Json) 'GET popular ok' "popular • HTTP $($pop.StatusCode)"
$new = Invoke-Api -Path 'get_new_recipes.php'
Assert-True ($new.Ok -and $new.Json) 'GET new ok' "new • HTTP $($new.StatusCode)"

Write-Step 'Public: unified search sort keys (name_asc / popular / latest)'
$srName = Invoke-Api -Path 'search_recipes_unified.php' -Query @{ sort='name_asc'; limit=$Limit }
Assert-True ($srName.Ok -and $srName.Json) 'search sort=name_asc ok' "search sort=name_asc • HTTP $($srName.StatusCode)"

# ตรวจเรียงตามชื่อแบบหยาบ ๆ (ถ้ามีข้อมูล)
try {
  $names = @()
  if ($srName.Json) {
    if ($srName.Json.data) { $names = $srName.Json.data | ForEach-Object { $_.name } }
    elseif ($srName.Json.recipes) { $names = $srName.Json.recipes | ForEach-Object { $_.name } }
  }
  if ($names.Count -gt 1) {
    $sorted = ($names | Sort-Object)
    Assert-True (@($names) -join '|' -eq (@($sorted) -join '|')) 'ชื่อเรียง ก→ฮ ถูกต้อง' 'คำเตือน: การเรียงชื่ออาจยังไม่เป็น ก→ฮ (ตรวจ sort=name_asc ใน BE)'
  }
} catch { Write-Host '  • ข้ามการตรวจเรียงชื่อ (โครงสร้าง JSON ไม่ตรง)' -ForegroundColor Yellow }

$srPop = Invoke-Api -Path 'search_recipes_unified.php' -Query @{ sort='popular'; limit=$Limit }
Assert-True ($srPop.Ok) 'search sort=popular ok' "search sort=popular • HTTP $($srPop.StatusCode)"
$srLatest = Invoke-Api -Path 'search_recipes_unified.php' -Query @{ sort='latest'; limit=$Limit }
Assert-True ($srLatest.Ok) 'search sort=latest ok' "search sort=latest • HTTP $($srLatest.StatusCode)"

Write-Step 'Public: suggestions'
$sg1 = Invoke-Api -Path 'get_recipe_suggestions.php' -Query @{ q='ข้าว' }
Assert-True ($sg1.Ok) 'recipe suggestions ok' 'recipe suggestions fail'
$sg2 = Invoke-Api -Path 'get_ingredient_suggestions.php' -Query @{ term='กระเทียม' }
Assert-True ($sg2.Ok) 'ingredient suggestions ok' 'ingredient suggestions fail'
$sg3 = Invoke-Api -Path 'get_group_suggestions.php' -Query @{ q='หมู' }
Assert-True ($sg3.Ok) 'group suggestions ok' 'group suggestions fail'

# ─────────────────────────────────────────────────────────────────
# 2) Auth endpoints (optional)
# ─────────────────────────────────────────────────────────────────
if ($RunAuthTests) {
  Write-Step 'Auth: login'
  if (-not $Email -or -not $Password) {
    Write-Fail 'ต้องระบุ -Email และ -Password เพื่อทดสอบ auth'; exit 1
  }
  $login = Invoke-Api -Path 'login.php' -Method 'POST' -Body @{ email=$Email; password=$Password }
  if (-not $login.Ok) { Write-Fail "login • HTTP $($login.StatusCode)"; exit 1 }
  Write-Pass 'login ok (คุกกี้ PHPSESSID ได้รับการบันทึกใน session)'

  Write-Step 'Auth: allergy list'
  $al = Invoke-Api -Path 'get_allergy_list.php'
  Assert-True ($al.Ok) 'get_allergy_list ok' 'get_allergy_list fail'

  Write-Step 'Auth: favorites (toggle)'
  # ใช้ id จาก popular/new ถ้ามี ไม่ควรทำลายข้อมูล (จะ toggle กลับ)
  $rid = $null
  try {
    if ($pop.Json -and $pop.Json.data) { $rid = $pop.Json.data[0].id }
    elseif ($pop.Json -and $pop.Json[0]) { $rid = $pop.Json[0].id }
  } catch {}
  if (-not $rid) { try { if ($new.Json -and $new.Json.data) { $rid = $new.Json.data[0].id } elseif ($new.Json[0]) { $rid = $new.Json[0].id } } catch {} }
  if ($rid) {
    $t1 = Invoke-Api -Path 'toggle_favorite.php' -Method 'POST' -Body @{ recipe_id="$rid"; favorite='1' }
    Assert-True ($t1.Ok) 'toggle favorite on ok' 'toggle favorite on fail'
    $t2 = Invoke-Api -Path 'toggle_favorite.php' -Method 'POST' -Body @{ recipe_id="$rid"; favorite='0' }
    Assert-True ($t2.Ok) 'toggle favorite off ok' 'toggle favorite off fail'
  } else {
    Write-Host '  • ข้าม toggle_favorite: หา recipe id ไม่ได้' -ForegroundColor Yellow
  }

  if ($RunWriteTests) {
    Write-Step 'Auth (write): cart add/remove (ไม่ทิ้งข้อมูล)'
    if (-not $rid) { Write-Host '  • ข้าม cart: หา recipe id ไม่ได้' -ForegroundColor Yellow }
    else {
      $add = Invoke-Api -Path 'add_cart_item.php' -Method 'POST' -Body @{ recipe_id="$rid"; nServings='1' }
      Assert-True ($add.Ok) 'add_cart_item ok' 'add_cart_item fail'
      $rm = Invoke-Api -Path 'remove_cart_item.php' -Method 'POST' -Body @{ recipe_id="$rid" }
      Assert-True ($rm.Ok) 'remove_cart_item ok' 'remove_cart_item fail'
    }
  }

  Write-Step 'Auth: logout'
  $logout = Invoke-Api -Path 'logout.php' -Method 'POST' -Body @{ }
  Assert-True ($logout.Ok) 'logout ok' 'logout fail'
}

Write-Host "`nเสร็จสิ้นการตรวจเบื้องต้น" -ForegroundColor Cyan
