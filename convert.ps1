# convert.ps1
# Converts LVGL 9.3 font files to LVGL 8.3.11 format


param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile = $null
)

# Extract font name for recommendations
$fontName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)

# Set output file if not provided
if (-not $OutputFile) {
    $dir = Split-Path $InputFile -Parent
    if ([string]::IsNullOrEmpty($dir)) {
        $dir = "."  # Use current directory if no path specified
    }
    $ext = [System.IO.Path]::GetExtension($InputFile)
    $OutputFile = Join-Path $dir "$fontName`_lvgl8$ext"
}

Write-Host "Converting LVGL 9.3 font to 8.3.11 format..." -ForegroundColor Cyan
Write-Host "Input:  $InputFile"
Write-Host "Output: $OutputFile"
Write-Host ""

# Recommendations
Write-Host "Recommendations:" -ForegroundColor Yellow
Write-Host "- Suggested output name: $fontName`_lvgl8.c (edit if needed)"
Write-Host "- Place in your project's fonts/ directory"
Write-Host "- Create header: $fontName`_lvgl8.h"
Write-Host "- LVGL include should be: #include `"lvgl/lvgl.h`" or #include `"lvgl.h`""
Write-Host ""

# Read the input file
if (-not (Test-Path $InputFile)) {
    Write-Error "Input file not found: $InputFile"
    exit 1
}

$content = Get-Content $InputFile -Raw

# Make the conversions
Write-Host "Applying conversions..." -ForegroundColor Green

# 1. Remove the build options line (Opts: ...)
$content = $content -replace ' \* Opts: [^\r\n]*\r?\n', ''

# 2. Define the header replacement first


# 3. Fix the header structure completely - simple direct approach
# Find the problematic header section and replace it entirely
$headerStart = $content.IndexOf('#ifdef __has_include')
$bitmapStart = $content.IndexOf('/*-----------------')

if ($headerStart -ge 0 -and $bitmapStart -gt $headerStart) {
    # Replace everything between the start and the bitmaps section
    $beforeHeader = $content.Substring(0, $headerStart)
    $afterHeader = $content.Substring($bitmapStart)
    

	$content = $afterHeader
    Write-Host "Header section replaced successfully" -ForegroundColor Yellow
} else {
    Write-Host "Could not locate header boundaries - manual review needed" -ForegroundColor Red
}

# 3. Remove ALL version conditionals around cache
$cacheReplacement = '$1' + "`n`nstatic lv_font_fmt_txt_glyph_cache_t cache;"
$content = $content -replace '#if LVGL_VERSION_MAJOR == 8\s*\n(/\*Store all the custom data of the font\*/)\s*\nstatic\s+lv_font_fmt_txt_glyph_cache_t\s+cache;\s*\n#endif', $cacheReplacement

# 4. Remove version conditionals from cache reference in font_dsc
$content = $content -replace '#if LVGL_VERSION_MAJOR == 8\s*\n\s*\.cache = &cache\s*\n#endif', '    .cache = &cache'

# 5. Remove complex font descriptor version conditionals
$content = $content -replace 'static const lv_font_fmt_txt_dsc_t font_dsc = \{\s*\n#else\s*\nstatic lv_font_fmt_txt_dsc_t font_dsc = \{\s*\n#endif', 'static const lv_font_fmt_txt_dsc_t font_dsc = {'

# 6. Remove complex font struct version conditionals
$content = $content -replace 'const lv_font_t ([a-zA-Z_][a-zA-Z0-9_]*) = \{\s*\n#else\s*\nlv_font_t ([a-zA-Z_][a-zA-Z0-9_]*) = \{\s*\n#endif', 'const lv_font_t $1 = {'

# 7. Remove any remaining #else and #endif orphans
$content = $content -replace '\n#else\s*\n.*?\n#endif', ''

# 8. Remove ALL LVGL version conditionals
$content = $content -replace '#if LVGL_VERSION_MAJOR >= 8\s*\n', ''
$content = $content -replace '#if LV_VERSION_CHECK\([^)]+\)\s*[^#]*\n', ''
$content = $content -replace '#endif[^\n]*\n', ''

# 9. Remove LVGL 9-specific fields
$content = $content -replace '\s*\.static_bitmap = 0,', ''
$content = $content -replace '\s*\.user_data = NULL,', ''
$content = $content -replace '\s*\.fallback = NULL,', ''

# 10. Fix the escaped newline characters (this is the key fix)
$content = $content -replace '`n', "`n"

# 11. Ensure proper LVGL 8 fields are present
if ($content -notmatch '\.subpx = LV_FONT_SUBPX_NONE') {
    $subpxReplacement = '$1' + "`n    .subpx = LV_FONT_SUBPX_NONE,"
    $content = $content -replace '(\.base_line = [^,]+,)', $subpxReplacement
}

if ($content -notmatch '\.underline_position') {
    $underlineReplacement = '$1' + "`n    .underline_position = -1,`n    .underline_thickness = 1,"
    $content = $content -replace '(\.subpx = LV_FONT_SUBPX_NONE,)', $underlineReplacement
}

# 12. Clean up extra whitespace and ensure proper formatting
$content = $content -replace '\n\s*\n\s*\n', "`n`n"
$content = $content -replace '\s+\n', "`n"


# 13. Final cleanup - remove any remaining stray directives
$content = $content -replace '#if [A-Z_]+ == \d+\s*\n', ''
$content = $content + '#endif'

	$content = '`n #if ' + $fontName.ToUpper() + '`n`n' + $content
	$content = '`n #endif`n' + $content
	$content = '`n #define ' + $fontName.ToUpper() + ' 1' + $content
	$content = '`n #ifndef ' + $fontName.ToUpper() + $content
	$content = '`n #endif`n' + $content
	$content = '`n     #include "../lvgl-8.3.11/lvgl.h"' + $content
	$content = '`n #else' + $content
	$content = '`n     #include "lvgl.h"' + $content
	$content = '`n #ifdef LV_LVGL_H_INCLUDE_SIMPLE' + $content
	$content = '`n #endif`n' + $content
	$content = '`n     #endif' + $content
	$content = '`n         #endif' + $content
	$content = '`n             #define LV_LVGL_H_INCLUDE_SIMPLE' + $content
	$content = '`n         #ifndef LV_LVGL_H_INCLUDE_SIMPLE' + $content
	$content = '`n    #if __has_include("lvgl.h")' + $content
	$content = '`n#ifdef __has_include`n' + $content
	$content = $beforeHeader + $content
	$content = $content -replace '`n', "`n"
	$content = $content -replace '(LVGL_VERSION_MAJOR == 6 && LVGL_VERSION_MINOR == 0)', "" 
	$content = $content -replace '#if !()', ""
	$content = $content -replace '\(\)', ""

# Write the output file
try {
    Set-Content -Path $OutputFile -Value $content -Encoding UTF8
    Write-Host "Conversion completed successfully!" -ForegroundColor Green
    Write-Host "Output saved to: $OutputFile" -ForegroundColor Green
    
    # Verify the output file was created
    if (Test-Path $OutputFile) {
        $size = (Get-Item $OutputFile).Length
        Write-Host "Output file size: $size bytes" -ForegroundColor Gray
    }
    
    # Quick validation
    $outputContent = Get-Content $OutputFile -Raw
    if ($outputContent -match '`n' -or $outputContent -match '#if LVGL_VERSION') {
        Write-Warning "Output may still contain formatting issues. Manual review recommended."
    } else {
        Write-Host "Basic validation passed - no obvious formatting issues detected." -ForegroundColor Green
    }
}
catch {
    Write-Error "Failed to write output file: $_"
    exit 1
}

Write-Host "`nConversion Summary:" -ForegroundColor Cyan
Write-Host "- Removed LVGL 9-specific version conditionals"
Write-Host "- Fixed font descriptor structure for LVGL 8"
Write-Host "- Ensured cache is properly declared and referenced"
Write-Host "- Removed unsupported LVGL 9 fields, fixed header"
Write-Host "- Fixed include paths and structure compatibility"
Write-Host "- Cleaned up escaped characters and formatting"
Write-Host "`nnnWarning:" -ForegroundColor Red
Write-Host "- Check that the lvgl.h pointer is correct for your script" -ForegroundColor Yellow
Write-Host "- on line 19. This is defualted to a '../lvgl-8.3.11/lvgl.h' by default" -ForegroundColor Yellow