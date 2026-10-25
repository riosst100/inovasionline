$ErrorActionPreference = "Stop"

# Generates the launcher icon for debug/profile builds: the release icon plus a red "TESTING" badge,
# written to android/app/src/{debug,profile}/res so those build types override src/main/res.
# Re-run after changing the release launcher icon (flutter_launcher_icons).
# Usage: powershell -ExecutionPolicy Bypass -File scripts\generate-debug-icon.ps1

Add-Type -AssemblyName System.Drawing

$root = Join-Path $PSScriptRoot ".."
$mainRes = Join-Path $root "android\app\src\main\res"
$sourceForeground = Join-Path $mainRes "drawable-xxxhdpi\ic_launcher_foreground.png"
$sourceLegacy = Join-Path $mainRes "mipmap-xxxhdpi\ic_launcher.png"

$fonts = New-Object System.Drawing.Text.PrivateFontCollection
$fonts.AddFontFile((Resolve-Path (Join-Path $root "assets\fonts\Montserrat-Bold.ttf")).Path)
$fontFamily = $fonts.Families[0]

$badgeColor = [System.Drawing.Color]::FromArgb(255, 0xD3, 0x2F, 0x2F)
$textColor = [System.Drawing.Color]::White

function New-Canvas([int]$size) {
    $bitmap = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bitmap)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    return @($bitmap, $g)
}

# Pill badge centered at ($cx, $cy), sizes in pixels.
function Draw-Badge($g, [float]$cx, [float]$cy, [float]$width, [float]$height) {
    $x = $cx - $width / 2
    $y = $cy - $height / 2
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($x, $y, $height, $height, 90, 180)
    $path.AddArc($x + $width - $height, $y, $height, $height, 270, 180)
    $path.CloseFigure()
    $g.FillPath((New-Object System.Drawing.SolidBrush $badgeColor), $path)

    $text = "TESTING"
    $fontSize = $height * 0.62
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    # Shrink the font until the text fits inside the pill with some padding.
    do {
        $font = New-Object System.Drawing.Font $fontFamily, $fontSize, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
        $measured = $g.MeasureString($text, $font)
        $fontSize *= 0.95
    } while ($measured.Width -gt ($width - $height * 0.5))
    $rect = New-Object System.Drawing.RectangleF $x, ($y + $height * 0.04), $width, $height
    $g.DrawString($text, $font, (New-Object System.Drawing.SolidBrush $textColor), $rect, $format)
}

# Adaptive-icon foreground (108dp). mipmap-anydpi-v26/ic_launcher.xml insets it by 16%, so the logo is
# shrunk and lifted to make room for the badge while both stay inside the launcher's circular safe zone.
function Write-Foreground([int]$size, [string]$outFile) {
    $source = [System.Drawing.Image]::FromFile($sourceForeground)
    $canvas = New-Canvas $size
    $bitmap = $canvas[0]; $g = $canvas[1]
    $logoScale = 0.8
    $logoSize = $size * $logoScale
    $g.DrawImage($source, ($size - $logoSize) / 2, ($size - $logoSize) / 2 - $size * 0.07, $logoSize, $logoSize)
    Draw-Badge $g ($size / 2) ($size * 0.735) ($size * 0.64) ($size * 0.15)
    Save-Png $bitmap $outFile
    $g.Dispose(); $source.Dispose()
}

# Legacy square icon for Android < 8.
function Write-Legacy([int]$size, [string]$outFile) {
    $source = [System.Drawing.Image]::FromFile($sourceLegacy)
    $canvas = New-Canvas $size
    $bitmap = $canvas[0]; $g = $canvas[1]
    $g.DrawImage($source, 0, 0, $size, $size)
    Draw-Badge $g ($size / 2) ($size * 0.82) ($size * 0.7) ($size * 0.18)
    Save-Png $bitmap $outFile
    $g.Dispose(); $source.Dispose()
}

function Save-Png($bitmap, [string]$outFile) {
    New-Item -ItemType Directory -Force (Split-Path $outFile) | Out-Null
    $bitmap.Save($outFile, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}

$densities = @{ "mdpi" = 1; "hdpi" = 1.5; "xhdpi" = 2; "xxhdpi" = 3; "xxxhdpi" = 4 }

foreach ($buildType in @("debug", "profile")) {
    $res = Join-Path $root "android\app\src\$buildType\res"
    foreach ($density in $densities.Keys) {
        $scale = $densities[$density]
        Write-Foreground ([int](108 * $scale)) (Join-Path $res "drawable-$density\ic_launcher_foreground.png")
        Write-Legacy ([int](48 * $scale)) (Join-Path $res "mipmap-$density\ic_launcher.png")
    }
    Write-Output "Wrote $res"
}
