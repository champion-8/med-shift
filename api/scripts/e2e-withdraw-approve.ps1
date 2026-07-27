# E2E: withdraw request -> admin approve
$ErrorActionPreference = "Stop"
$base = "http://localhost:5080"

function Login($email, $password) {
  $r = Invoke-RestMethod -Uri "$base/api/auth/login" -Method POST -ContentType "application/json" `
    -Body (@{ email = $email; password = $password } | ConvertTo-Json)
  if (-not $r.success) { throw "login failed $email" }
  return $r.data
}

function Api($method, $path, $token, $body = $null) {
  $headers = @{ Authorization = "Bearer $token" }
  $params = @{ Uri = "$base$path"; Method = $method; Headers = $headers }
  if ($null -ne $body) {
    $params.ContentType = "application/json"
    $params.Body = ($body | ConvertTo-Json -Depth 6)
  }
  try { return Invoke-RestMethod @params }
  catch {
    $msg = $_.ErrorDetails.Message
    if (-not $msg) { $msg = $_.Exception.Message }
    throw "$method $path => $msg"
  }
}

Write-Host "=== Login staff + admin ==="
$staff = Login "ui.nurse120741@test.local" "Password1!"
$admin = Login "admin@medshift.local" "Admin@12345"

$wallet = Api GET "/api/staff/wallet" $staff.accessToken
$before = [decimal]$wallet.data.balance
Write-Host "balance_before=$before"
if ($before -lt 100) { throw "need balance >= 100 (run hire-checkin-pay first)" }

# ensure bank verified (name must match first+last)
$profile = Api GET "/api/staff/profile" $staff.accessToken
$accountName = "$($profile.data.firstName) $($profile.data.lastName)".Trim()
if (-not $profile.data.bankAccountNumber -or -not $profile.data.bankAccountVerified) {
  Api PUT "/api/staff/profile" $staff.accessToken @{
    firstName = $profile.data.firstName
    lastName = $profile.data.lastName
    phone = $profile.data.phone
    specialty = $profile.data.specialty
    licenseNumber = $profile.data.licenseNumber
    yearsExperience = 1
    bankName = "Kasikorn"
    bankAccountNumber = "1234567890"
    bankAccountName = $accountName
    bankAccountVerified = $true
    skills = @()
  } | Out-Null
  Write-Host "bank verified as $accountName"
}

$amount = 100
Write-Host "=== Staff withdraw $amount ==="
Api POST "/api/staff/wallet/withdraw" $staff.accessToken @{ amount = $amount } | Out-Null

$mid = Api GET "/api/staff/wallet" $staff.accessToken
$afterWithdraw = [decimal]$mid.data.balance
Write-Host "balance_after_withdraw=$afterWithdraw"
if ($afterWithdraw -ne ($before - $amount)) { throw "balance after withdraw wrong" }

$pendingTx = @($mid.data.transactions | Where-Object { $_.type -eq "Withdrawal" -and $_.status -eq "Pending" })
Write-Host "pending_withdraw_txns=$($pendingTx.Count)"

Write-Host "=== Admin pending list ==="
$pend = Api GET "/api/admin/withdrawals/pending" $admin.accessToken
$item = @($pend.data | Where-Object { [decimal]$_.amount -eq $amount } | Select-Object -First 1)
if (-not $item) { throw "pending withdrawal not found" }
$wid = $item.id
Write-Host "withdrawalId=$wid staff=$($item.staffName)"

Write-Host "=== Admin approve ==="
Api POST "/api/admin/withdrawals/$wid/approve" $admin.accessToken | Out-Null

$final = Api GET "/api/staff/wallet" $staff.accessToken
$finalBal = [decimal]$final.data.balance
$completed = @($final.data.transactions | Where-Object { $_.type -eq "Withdrawal" -and $_.status -eq "Completed" -and [math]::Abs([decimal]$_.amount) -eq $amount })
$notifs = Api GET "/api/staff/notifications" $staff.accessToken
$approveNotif = @($notifs.data | Where-Object { $_.title -like "*ถอน*" -or $_.message -like "*$amount*" })

Write-Host "balance_final=$finalBal (unchanged after approve expected)"
Write-Host "completed_withdraw_txns=$($completed.Count)"
Write-Host "related_notifs=$($approveNotif.Count)"

if ($finalBal -ne $afterWithdraw) { throw "approve should not change balance again" }
if ($completed.Count -lt 1) { throw "withdrawal txn not marked Completed" }

Write-Host "=== Announcements ==="
$ann = Api GET "/api/staff/announcements/active?locale=th" $staff.accessToken
Write-Host "announcements=$($ann.data.Count)"
if ($ann.data.Count -lt 1) { throw "expected seeded announcement" }
Write-Host "  $($ann.data[0].title)"

Write-Host ""
Write-Host "E2E OK: withdraw -> admin approve + announcements"
