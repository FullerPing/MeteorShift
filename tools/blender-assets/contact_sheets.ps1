Add-Type -AssemblyName System.Drawing
$assetRoot = 'Z:\final-final-actual-final\MeteorShift\blender'
$reviewPath = Join-Path $assetRoot 'review'
[System.IO.Directory]::CreateDirectory($reviewPath) | Out-Null
foreach ($category in @('equipment','pets','eggs','meteor','rocks','map','items','meteor/minerals','props')) {
    if (-not (Test-Path -LiteralPath (Join-Path $assetRoot $category))) { continue }
    $files = @(Get-ChildItem -LiteralPath (Join-Path $assetRoot $category) -Filter '*.png' | Sort-Object Name)
    if ($files.Count -eq 0) { continue }
    $columns = 4
    $rows = [Math]::Ceiling($files.Count / $columns)
    $bitmap = New-Object System.Drawing.Bitmap(($columns * 256), ([int]$rows * 284))
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::FromArgb(22,29,44))
    $font = New-Object System.Drawing.Font('Arial', 11)
    for ($i=0; $i -lt $files.Count; $i++) {
        $x = ($i % $columns) * 256
        $y = [Math]::Floor($i / $columns) * 284
        $source = [System.Drawing.Image]::FromFile($files[$i].FullName)
        $graphics.DrawImage($source, [int]$x, [int]$y, 256, 256)
        $graphics.DrawString($files[$i].BaseName, $font, [System.Drawing.Brushes]::White, [single]($x+8), [single]($y+260))
        $source.Dispose()
    }
    $bitmap.Save((Join-Path $reviewPath (($category -replace '/', '-') + '.png')), [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $font.Dispose(); $bitmap.Dispose()
}
Write-Output 'Saved nine review sheets.'
