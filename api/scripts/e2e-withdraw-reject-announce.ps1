# E2E: withdraw reject (refund) + admin create announcement
$ErrorActionPreference = "Stop"
$base = "http://localhost:5080"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

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
    $params.ContentType = "application/json; charset=utf-8"
    $params.Body = [System.Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Depth 6))
  }
  try { return Invoke-RestMethod @params }
  catch {
    $msg = $_.ErrorDetails.Message
    if (-not $msg) { $msg = $_.Exception.Message }
    throw "$method $path => $msg"
  }
}

Write-Host "=== Login ==="
$staff = Login "ui.nurse120741@test.local" "Password1!"
$admin = Login "admin@medshift.local" "Admin@12345"

$wallet = Api GET "/api/staff/wallet" $staff.accessToken
$before = [decimal]$wallet.data.balance
Write-Host "balance_before=$before"
if ($before -lt 50) { throw "need balance >= 50" }

$profile = Api GET "/api/staff/profile" $staff.accessToken
$accountName = "$($profile.data.firstName) $($profile.data.lastName)".Trim()
if (-not $profile.data.bankAccountVerified) {
  Api PUT "/api/staff/profile" $staff.accessToken @{
    firstName = $profile.data.firstName
    lastName = $profile.data.lastName
    phone = $profile.data.phone
    specialty = $profile.data.specialty
    licenseNumber = $profile.data.licenseNumber
    yearsExperience = 1
    bankName = $(if ($profile.data.bankName) { $profile.data.bankName } else { "Kasikorn" })
    bankAccountNumber = $(if ($profile.data.bankAccountNumber) { $profile.data.bankAccountNumber } else { "1234567890" })
    bankAccountName = $accountName
    bankAccountVerified = $true
  } | Out-Null
  Write-Host "bank verified"
}

$amount = 50
Write-Host "=== Staff withdraw $amount ==="
Api POST "/api/staff/wallet/withdraw" $staff.accessToken @{ amount = $amount } | Out-Null
$mid = Api GET "/api/staff/wallet" $staff.accessToken
$afterWithdraw = [decimal]$mid.data.balance
if ($afterWithdraw -ne ($before - $amount)) { throw "withdraw balance wrong" }

$pend = Api GET "/api/admin/withdrawals/pending" $admin.accessToken
$item = @($pend.data | Where-Object { [decimal]$_.amount -eq $amount } | Select-Object -First 1)
if (-not $item) { throw "pending not found" }
$wid = $item.id
Write-Host "withdrawalId=$wid"

Write-Host "=== Admin reject ==="
Api POST "/api/admin/withdrawals/$wid/reject" $admin.accessToken @{ reason = "E2E reject test" } | Out-Null

$final = Api GET "/api/staff/wallet" $staff.accessToken
$finalBal = [decimal]$final.data.balance
$refund = @($final.data.transactions | Where-Object { $_.type -eq "Refund" -and [decimal]$_.amount -eq $amount })
$cancelled = @($final.data.transactions | Where-Object { $_.type -eq "Withdrawal" -and $_.status -eq "Cancelled" })
$notifs = Api GET "/api/staff/notifications" $staff.accessToken
$rejNotif = @($notifs.data | Where-Object { $_.type -eq "System" -and $_.message -like "*E2E reject*" })

Write-Host "balance_final=$finalBal"
Write-Host "refund_txns=$($refund.Count) cancelled_withdraw=$($cancelled.Count) notifs=$($rejNotif.Count)"
if ($finalBal -ne $before) { throw "reject should refund to original balance" }
if ($refund.Count -lt 1) { throw "missing refund txn" }

Write-Host "=== Admin create announcement ==="
$stamp = Get-Date -Format HHmmss
Api POST "/api/admin/announcements" $admin.accessToken @{
  titleTh = "E2E announce TH $stamp"
  titleEn = "E2E announce EN $stamp"
  messageTh = "E2E message TH"
  messageEn = "E2E message EN"
  type = "info"
} | Out-Null

$ann = Api GET "/api/staff/announcements/active?locale=th" $staff.accessToken
$found = @($ann.data | Where-Object { $_.title -like "*$stamp*" })
Write-Host "announcements=$($ann.data.Count) matched=$($found.Count)"
if ($found.Count -lt 1) { throw "new announcement not visible to staff" }

Write-Host ""
Write-Host "E2E OK: withdraw reject refund + announcement create"
