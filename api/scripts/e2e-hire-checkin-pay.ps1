# E2E: Hire -> Check-in -> Complete & pay
$ErrorActionPreference = "Stop"
$base = "http://localhost:5080"

function Login($email, $password) {
  $r = Invoke-RestMethod -Uri "$base/api/auth/login" -Method POST -ContentType "application/json" `
    -Body (@{ email = $email; password = $password } | ConvertTo-Json)
  if (-not $r.success) { throw "login failed: $email $($r.message)" }
  return $r.data
}

function Api($method, $path, $token, $body = $null) {
  $headers = @{ Authorization = "Bearer $token" }
  $params = @{
    Uri = "$base$path"
    Method = $method
    Headers = $headers
  }
  if ($null -ne $body) {
    $params.ContentType = "application/json"
    $params.Body = ($body | ConvertTo-Json -Depth 8)
  }
  try {
    return Invoke-RestMethod @params
  } catch {
    $msg = $_.ErrorDetails.Message
    if (-not $msg) { $msg = $_.Exception.Message }
    throw "$method $path => $msg"
  }
}

Write-Host "=== 1. Login clinic + staff ==="
$clinic = Login "ui.clinic120741@test.local" "Password1!"
$staff = Login "ui.nurse120741@test.local" "Password1!"
$staffProfileId = $staff.profile.id
Write-Host "clinic org status: $($clinic.profile.status)"
Write-Host "staff status: $($staff.profile.status) id=$staffProfileId"

if ($clinic.profile.status -ne "Approved") { throw "clinic not approved" }
if ($staff.profile.status -ne "Approved") { throw "staff not approved" }

Write-Host "=== 2. Create job ==="
$dayOffset = Get-Random -Minimum 3 -Maximum 40
$start = [DateTime]::UtcNow.AddDays($dayOffset).AddHours(2).ToString("o")
$end = [DateTime]::UtcNow.AddDays($dayOffset).AddHours(6).ToString("o")
$jobBody = @{
  title = "E2E Checkin Pay $(Get-Date -Format HHmmss)"
  description = "End-to-end hire check-in complete pay"
  locationName = "Bangkok Clinic"
  address = "123 Test Rd"
  latitude = 13.7563
  longitude = 100.5018
  startTime = $start
  endTime = $end
  hourlyRate = 500
  requiredSkills = @("Nursing")
  minReliabilityScore = 50
  confirmGatewayPayment = $true
}
$jobResp = Api POST "/api/clinic/jobs" $clinic.accessToken $jobBody
$jobId = $jobResp.data.id
$totalPay = $jobResp.data.totalPay
$platformFee = $jobResp.data.platformFee
$totalCharged = $jobResp.data.totalCharged
$paymentStatus = $jobResp.data.paymentStatus
Write-Host "job=$jobId totalPay=$totalPay platformFee=$platformFee totalCharged=$totalCharged payment=$paymentStatus"
if (-not $paymentStatus -or $paymentStatus -ne "Held") { throw "expected payment Held, got $paymentStatus" }
if (-not $totalCharged -or [decimal]$totalCharged -le [decimal]$totalPay) { throw "totalCharged should include platform fee" }

Write-Host "=== 3. Staff wallet before ==="
$walletBefore = Api GET "/api/staff/wallet" $staff.accessToken
Write-Host "balance_before=$($walletBefore.data.balance)"

Write-Host "=== 4. Staff apply ==="
Api POST "/api/staff/jobs/$jobId/apply" $staff.accessToken | Out-Null
Write-Host "applied"

Write-Host "=== 5. Clinic hire ==="
Api POST "/api/clinic/jobs/$jobId/applicants/$staffProfileId/hire" $clinic.accessToken | Out-Null
Write-Host "hired"

Write-Host "=== 6. Check-in requirements ==="
$reqs = Api GET "/api/staff/jobs/$jobId/check-in-requirements" $staff.accessToken
$reqCount = @($reqs.data).Count
Write-Host "requirements=$reqCount"
if ($reqCount -gt 0) {
  $reqs.data | ForEach-Object { Write-Host "  step=$($_.stepNumber) title=$($_.title)" }
}
$steps = @($reqs.data | ForEach-Object { $_.stepNumber })
if ($steps.Count -eq 0) { $steps = @() }

Write-Host "=== 7. Staff check-in ==="
Api POST "/api/staff/jobs/$jobId/check-in" $staff.accessToken @{
  completedSteps = $steps
  latitude = 13.7563
  longitude = 100.5018
  accuracyMeters = 10
} | Out-Null
Write-Host "checked-in"

Write-Host "=== 8. Staff start work ==="
Api POST "/api/staff/jobs/$jobId/start" $staff.accessToken | Out-Null
$jobAfterStart = Api GET "/api/staff/jobs/$jobId" $staff.accessToken
Write-Host "status_after_start=$($jobAfterStart.data.status)"
if ($jobAfterStart.data.status -ne "InProgress") {
  throw "expected InProgress after start, got $($jobAfterStart.data.status)"
}

Write-Host "=== 9. Staff complete work & pay ==="
Api POST "/api/staff/jobs/$jobId/complete" $staff.accessToken | Out-Null
$jobAfterComplete = Api GET "/api/staff/jobs/$jobId" $staff.accessToken
Write-Host "status_after_complete=$($jobAfterComplete.data.status)"
if ($jobAfterComplete.data.status -ne "Completed") {
  throw "expected Completed after staff complete, got $($jobAfterComplete.data.status)"
}

Write-Host "=== 10. Verify wallet + notifications ==="
$walletAfter = Api GET "/api/staff/wallet" $staff.accessToken
$notifs = Api GET "/api/staff/notifications" $staff.accessToken
$payNotif = @($notifs.data | Where-Object { $_.type -eq "PaymentReceived" -and $_.jobId -eq $jobId })
$hireNotif = @($notifs.data | Where-Object { $_.jobId -eq $jobId -and $_.title -like "*งาน*" })

Write-Host "balance_after=$($walletAfter.data.balance)"
Write-Host "txns=$($walletAfter.data.transactions.Count)"
Write-Host "payment_notifs=$($payNotif.Count)"
if ($payNotif.Count -gt 0) { Write-Host "  $($payNotif[0].message)" }

$before = [decimal]$walletBefore.data.balance
$after = [decimal]$walletAfter.data.balance
$expected = $before + [decimal]$totalPay
if ($after -ne $expected) {
  throw "wallet mismatch: before=$before + totalPay=$totalPay => expected=$expected got=$after"
}
if ($payNotif.Count -lt 1) { throw "missing PaymentReceived notification" }

Write-Host ""
Write-Host "E2E OK: hire -> check-in -> start -> staff-complete & pay"
Write-Host "  jobId=$jobId"
Write-Host "  paid=$totalPay"
Write-Host "  balance=$after"
