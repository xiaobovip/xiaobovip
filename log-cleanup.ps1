# ============================================
# 日志清理脚本 - Windows PowerShell
# 功能：清理指定目录下的日志文件，保留7天备份
# 备份路径：E:\shell
# ============================================

# ---------- 配置项 ----------
# 需要清理的日志目录（可添加多个）
$logDirs = @(
    "C:\inetpub\logs",
    "C:\Windows\Temp"
)

# 保留天数
$retainDays = 7

# 备份根目录
$backupRoot = "E:\shell"

# 日志文件匹配模式
$logPattern = "*.log"

# 当前日期
$today = Get-Date
$cutoffDate = $today.AddDays(-$retainDays)
$dateStr = $today.ToString("yyyyMMdd")

# ---------- 初始化 ----------
# 创建备份目录
$backupDir = Join-Path $backupRoot "backup_$dateStr"
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Write-Host "[信息] 创建备份目录: $backupDir" -ForegroundColor Green
}

# 脚本运行日志
$scriptLog = Join-Path $backupRoot "cleanup_$dateStr.log"

function Write-Log {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] $message"
    Write-Host $entry
    Add-Content -Path $scriptLog -Value $entry -Encoding UTF8
}

# ---------- 清理过期备份（超过7天） ----------
Write-Log "===== 开始清理过期备份 ====="
$oldBackups = Get-ChildItem -Path $backupRoot -Directory -Filter "backup_*" -ErrorAction SilentlyContinue
$cleanedCount = 0

foreach ($bk in $oldBackups) {
    # 从目录名提取日期 backup_20260419
    if ($bk.Name -match '^backup_(\d{8})$') {
        $bkDate = [datetime]::ParseExact($Matches[1], "yyyyMMdd", $null)
        if ($bkDate -lt $cutoffDate) {
            Write-Log "删除过期备份: $($bk.FullName)"
            Remove-Item -Path $bk.FullName -Recurse -Force
            $cleanedCount++
        }
    }
}
Write-Log "共清理 $cleanedCount 个过期备份目录"

# ---------- 备份并清理日志文件 ----------
Write-Log "===== 开始备份并清理日志文件 ====="
$totalCopied = 0
$totalDeleted = 0

foreach ($dir in $logDirs) {
    if (-not (Test-Path $dir)) {
        Write-Log "[警告] 日志目录不存在: $dir"
        continue
    }

    $logFiles = Get-ChildItem -Path $dir -Filter $logPattern -File -Recurse -ErrorAction SilentlyContinue

    foreach ($file in $logFiles) {
        # 超过保留天数的日志文件
        if ($file.LastWriteTime -lt $cutoffDate) {
            # 构建备份子目录（保留原始相对路径结构）
            $relativePath = $file.FullName.Substring($dir.Length).TrimStart("\")
            $destDir = Join-Path $backupDir $relativePath
            $destPath = Join-Path $destDir $file.Name

            # 创建目标目录并复制
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item -Path $file.FullName -Destination $destPath -Force
            $totalCopied++

            # 删除原文件
            Remove-Item -Path $file.FullName -Force
            $totalDeleted++

            Write-Log "备份并删除: $($file.FullName) -> $destPath"
        }
    }
}

Write-Log "共备份 $totalCopied 个文件，删除 $totalDeleted 个文件"

# ---------- 清理过期的脚本运行日志（超过7天） ----------
Write-Log "===== 清理过期运行日志 ====="
$oldLogs = Get-ChildItem -Path $backupRoot -Filter "cleanup_*.log" -File -ErrorAction SilentlyContinue
$logCleaned = 0

foreach ($lg in $oldLogs) {
    if ($lg.LastWriteTime -lt $cutoffDate) {
        Remove-Item -Path $lg.FullName -Force
        $logCleaned++
    }
}
Write-Log "共清理 $logCleaned 个过期运行日志"

# ---------- 完成 ----------
Write-Log "===== 清理任务完成 ====="
Write-Host ""
Write-Host "备份目录: $backupDir" -ForegroundColor Cyan
Write-Host "运行日志: $scriptLog" -ForegroundColor Cyan
