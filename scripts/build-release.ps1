# PowerShell Release Build + Publish Script for Teman Kereta
#
# One command does everything: build the release APK, upload it to
# Cloudflare R2 (dl.temankereta.web.id), publish the app_releases row, and
# broadcast a push notification to every registered device -- no admin
# panel steps required (that UI is still there if you'd rather publish by
# hand for a build under 50MB, but this script is the "just deploy" path
# and the only one that works for larger builds).
param (
    [string]$SupabaseUrl = "https://slcttxbxcdrsavgugzdy.supabase.co",
    [string]$SupabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNsY3R0eGJ4Y2Ryc2F2Z3VnemR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU4NDM5NjksImV4cCI6MjEwMTQxOTk2OX0.o-N_03nF0ZmlurmHM3_ogRDupnXLOPY2ztAU8zU0kbE",
    [string]$SentryDsn = "",
    [string]$FlutterSdkPath = "C:\Users\aziz\develop\flutter\bin\flutter.bat",
    [string]$DbUrl = "postgresql://postgres.slcttxbxcdrsavgugzdy:.Keenan14062@aws-1-ap-northeast-2.pooler.supabase.com:5432/postgres",
    [string]$Changelog = "",
    [Nullable[int]]$MinSupportedVersionCode = $null,
    [switch]$SkipPublish
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Teman Kereta - Production Release Build " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if (-not (Test-Path $FlutterSdkPath)) {
    Write-Host "[ERROR] Flutter SDK not found at $FlutterSdkPath" -ForegroundColor Red
    exit 1
}

Write-Host "`n[1/2] Running Flutter Code Analysis..." -ForegroundColor Yellow
& $FlutterSdkPath analyze --no-fatal-infos --no-fatal-warnings
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARNING] Flutter analyze returned code $LASTEXITCODE, continuing build..." -ForegroundColor Yellow
} else {
    Write-Host "[OK] Code analysis clean!" -ForegroundColor Green
}

Write-Host "`n[2/2] Building Production APK (.apk, arm only)..." -ForegroundColor Yellow
# Sideload-only distribution (no Play Store) has no use for a .aab. A
# "universal" single APK bundles native libs for every CPU architecture at
# once (arm64-v8a, armeabi-v7a, x86, x86_64), inflating the download size.
# Includes arm64-v8a (virtually every real phone), armeabi-v7a (32-bit ARM --
# NOT vanishingly rare: a real user's Samsung Galaxy A10 (SM-A105G, Android
# 11) reports armeabi-v7a as its only supported ABI via
# `getprop ro.product.cpu.abilist`, so an arm64-only APK throws
# `UnsatisfiedLinkError` on native lib load and force-closes instantly on
# launch, confirmed via logcat 2026-09-01), AND x86_64 (Android Studio
# emulators, needed for dev/test builds -- an arm64-only APK throws
# `UnsatisfiedLinkError: libflutter.so is for EM_AARCH64 instead of
# EM_X86_64` and crashes immediately on an x86_64 emulator, confirmed via
# logcat 2026-08-23).
& $FlutterSdkPath build apk --release --target-platform android-arm,android-arm64,android-x64 `
    --dart-define=APP_ENV=production `
    --dart-define=TRANSIT_PROVIDER=local_supabase `
    --dart-define=SUPABASE_URL=$SupabaseUrl `
    --dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey `
    --dart-define=SUPABASE_ENABLED=true `
    --dart-define=FIREBASE_ENABLED=true `
    --dart-define=SENTRY_DSN=$SentryDsn

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] APK build failed with exit code $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}

New-Item -ItemType Directory -Force -Path "dist" | Out-Null
$pubspecVersionFull = (Select-String -Path "pubspec.yaml" -Pattern "^version:\s*(.+)$").Matches[0].Groups[1].Value.Trim()
$versionParts = $pubspecVersionFull -split "\+"
$versionName = $versionParts[0]
$versionCode = [int]$versionParts[1]
# Gradle's own output stays `app-release.apk` because `flutter build apk`
# looks that filename up by hand and fails if it is renamed (see the
# matching comment in android/app/build.gradle.kts). Everything a human
# ever sees -- the local dist copy, the R2 object, the download link -- is
# named for the app and its version instead.
$apkFileName = "Teman-Kereta.$versionName.apk"
Copy-Item -Path "build\app\outputs\flutter-apk\app-release.apk" -Destination "dist\$apkFileName" -Force
$sizeMb = [math]::Round((Get-Item "dist\$apkFileName").Length / 1MB, 1)
Write-Host "[OK] APK created at dist\$apkFileName ($sizeMb MB, version $versionName+$versionCode)" -ForegroundColor Green

if ($SkipPublish) {
    Write-Host "`n-SkipPublish set: APK built but not uploaded/published. Use the admin panel's /releases page if you want to publish it by hand." -ForegroundColor Cyan
    exit 0
}

Write-Host "`n[3/3] Publishing release (upload + database row + push notification)..." -ForegroundColor Yellow

$serviceRoleLine = Select-String -Path "admin\.env.local" -Pattern "^SUPABASE_SERVICE_ROLE_KEY=(.+)$"
if (-not $serviceRoleLine) {
    Write-Host "[ERROR] Could not find SUPABASE_SERVICE_ROLE_KEY in admin\.env.local -- cannot publish. Re-run with -SkipPublish to just build." -ForegroundColor Red
    exit 1
}
$serviceRoleKey = $serviceRoleLine.Matches[0].Groups[1].Value.Trim()

# Hosted on Cloudflare R2 (bucket temankereta-releases) behind the custom
# domain dl.temankereta.web.id -- NOT Supabase Storage. Supabase's project-
# wide Storage file-size limit is 50MB and raising it via the CLI
# (`supabase --experimental config push`) is blocked by an unrelated
# "vector buckets require a paid plan" error even though only the file-size
# setting was being changed (confirmed 2026-08-23); R2 has no such cap. The
# custom domain matters too -- R2's own shared `*.r2.dev` public URLs were
# confirmed unreachable for real users (ISP-level blocking), while a
# domain under temankereta.web.id (already proven reachable) is not.
$objectPath = $apkFileName
Write-Host "Uploading to Cloudflare R2 (temankereta-releases/$objectPath)..." -ForegroundColor Yellow
Push-Location admin
npx wrangler r2 object put "temankereta-releases/$objectPath" `
    --file "..\dist\$apkFileName" `
    --content-type "application/vnd.android.package-archive" `
    --remote
$uploadExitCode = $LASTEXITCODE
Pop-Location
if ($uploadExitCode -ne 0) {
    Write-Host "[ERROR] Upload to R2 failed." -ForegroundColor Red
    exit 1
}
$apkUrl = "https://dl.temankereta.web.id/$objectPath"

Write-Host "Verifying the upload is actually reachable at $apkUrl ..." -ForegroundColor Yellow
$verifyStatus = curl.exe -sS -o NUL -w "%{http_code}" --max-time 30 $apkUrl
if ($verifyStatus -ne "200") {
    Write-Host "[ERROR] Verification failed -- $apkUrl returned HTTP $verifyStatus, not 200. Refusing to publish a broken link." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Uploaded and verified: $apkUrl" -ForegroundColor Green

$escapedChangelog = $Changelog.Replace("'", "''")
$minSupportedSql = if ($null -ne $MinSupportedVersionCode) { $MinSupportedVersionCode } else { "null" }
$changelogSql = if ($Changelog) { "'$escapedChangelog'" } else { "null" }
$sql = "insert into public.app_releases (version_code, version_name, apk_url, changelog, min_supported_version_code) values ($versionCode, '$versionName', '$apkUrl', $changelogSql, $minSupportedSql) on conflict (version_code) do update set version_name = excluded.version_name, apk_url = excluded.apk_url, changelog = excluded.changelog, min_supported_version_code = excluded.min_supported_version_code;"

Write-Host "Publishing app_releases row (version_code=$versionCode)..." -ForegroundColor Yellow
npx supabase db query $sql --db-url $DbUrl
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to write the app_releases row -- APK is uploaded but not published. Retry the SQL manually, or use the admin panel." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Release published: version $versionName ($versionCode)" -ForegroundColor Green

Write-Host "Broadcasting push notification to registered devices..." -ForegroundColor Yellow
try {
    $tokenQueryResult = npx supabase db query "select distinct user_id from public.device_tokens;" --db-url $DbUrl --output-format json | ConvertFrom-Json
    $userIds = @($tokenQueryResult.rows | ForEach-Object { $_.user_id })
} catch {
    $userIds = @()
}

if ($userIds.Count -eq 0) {
    Write-Host "[INFO] No registered devices yet -- skipping push broadcast." -ForegroundColor Cyan
} else {
    $pushPayload = @{
        user_ids = $userIds
        title    = "Pembaruan Teman Kereta tersedia"
        body     = "Versi $versionName sudah bisa diunduh."
    } | ConvertTo-Json -Compress

    $pushPayloadFile = New-TemporaryFile
    [System.IO.File]::WriteAllText($pushPayloadFile, $pushPayload, [System.Text.UTF8Encoding]::new($false))
    curl.exe -sS -X POST "$SupabaseUrl/functions/v1/send-push-notification" `
        -H "apikey: $SupabaseAnonKey" `
        -H "Authorization: Bearer $SupabaseAnonKey" `
        -H "Content-Type: application/json" `
        --data "@$pushPayloadFile"
    Remove-Item $pushPayloadFile -Force
}
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host " RELEASE $versionName ($versionCode) PUBLISHED " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
