# convert.ps1
# Converts LVGL 9.3 font files to LVGL 8.3.11 format with unique variable names

param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile = $null
)

# Extract font name for recommendations and variable prefixes
$fontName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
$varPrefix = $fontName -replace '[^a-zA-Z0-9_]', '_'  # Sanitize for C variable names

# Set output file if not provided
if (-not $OutputFile) {
    $dir = Split-Path $InputFile -Parent
    if ([string]::IsNullOrEmpty($dir)) {
        $dir = "."
    }
    $ext = [System.IO.Path]::GetExtension($InputFile)
    $OutputFile = Join-Path $dir "$fontName`_lvgl8$ext"
}

Write-Host "Converting LVGL 9.3 font to 8.3.11 format..." -ForegroundColor Cyan
Write-Host "Input:  $InputFile"
Write-Host "Output: $OutputFile"
Write-Host "Variable prefix: $varPrefix`_" -ForegroundColor Yellow
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

Write-Host "Applying conversions..." -ForegroundColor Green

# 1. Remove the build options line (Opts: ...)
$content = $content -replace ' \* Opts: [^\r\n]*\r?\n', ''

# 2. Fix the header structure
$headerStart = $content.IndexOf('#ifdef __has_include')
$bitmapStart = $content.IndexOf('/*-----------------')

if ($headerStart -ge 0 -and $bitmapStart -gt $headerStart) {
    $beforeHeader = $content.Substring(0, $headerStart)
    $afterHeader = $content.Substring($bitmapStart)
    $content = $afterHeader
    Write-Host "Header section replaced successfully" -ForegroundColor Yellow
} else {
    Write-Host "Could not locate header boundaries - manual review needed" -ForegroundColor Red
}

# 3. CRITICAL: Rename static variables to avoid conflicts between multiple fonts
Write-Host "Renaming static variables with prefix: $varPrefix`_" -ForegroundColor Cyan

# Define all the static variable names that need to be prefixed
$staticVars = @(
    @{Pattern = 'static LV_ATTRIBUTE_LARGE_CONST const uint8_t glyph_bitmap\[\]'; Replacement = "static LV_ATTRIBUTE_LARGE_CONST const uint8_t $($varPrefix)_glyph_bitmap[]"},
    @{Pattern = 'static const lv_font_fmt_txt_glyph_dsc_t glyph_dsc\[\]'; Replacement = "static const lv_font_fmt_txt_glyph_dsc_t $($varPrefix)_glyph_dsc[]"},
    @{Pattern = 'static const uint16_t unicode_list_(\d+)\[\]'; Replacement = "static const uint16_t $($varPrefix)_unicode_list_`$1[]"},
    @{Pattern = 'static const lv_font_fmt_txt_cmap_t cmaps\[\]'; Replacement = "static const lv_font_fmt_txt_cmap_t $($varPrefix)_cmaps[]"},
    @{Pattern = 'static const uint8_t kern_pair_glyph_ids\[\]'; Replacement = "static const uint8_t $($varPrefix)_kern_pair_glyph_ids[]"},
    @{Pattern = 'static const int8_t kern_pair_values\[\]'; Replacement = "static const int8_t $($varPrefix)_kern_pair_values[]"},
    @{Pattern = 'static const lv_font_fmt_txt_kern_pair_t kern_pairs'; Replacement = "static const lv_font_fmt_txt_kern_pair_t $($varPrefix)_kern_pairs"},
    @{Pattern = 'static lv_font_fmt_txt_glyph_cache_t cache;'; Replacement = "static lv_font_fmt_txt_glyph_cache_t $($varPrefix)_cache;"},
    @{Pattern = 'static const lv_font_fmt_txt_dsc_t font_dsc'; Replacement = "static const lv_font_fmt_txt_dsc_t $($varPrefix)_font_dsc"}
)

foreach ($var in $staticVars) {
    $content = $content -replace $var.Pattern, $var.Replacement
}

# 4. Update references to renamed variables in structures
Write-Host "Updating variable references..." -ForegroundColor Cyan

# Update glyph_ids and values references
$content = $content -replace '\.glyph_ids = glyph_bitmap,', ".glyph_ids = $($varPrefix)_glyph_bitmap,"
$content = $content -replace '\.glyph_dsc = glyph_dsc,', ".glyph_dsc = $($varPrefix)_glyph_dsc,"
$content = $content -replace '\.cmaps = cmaps,', ".cmaps = $($varPrefix)_cmaps,"
$content = $content -replace '\.kern_dsc = &kern_pairs,', ".kern_dsc = &$($varPrefix)_kern_pairs,"
$content = $content -replace '\.cache = &cache', ".cache = &$($varPrefix)_cache"
$content = $content -replace '\.dsc = &font_dsc,', ".dsc = &$($varPrefix)_font_dsc,"

# Update kern_pairs structure references
$content = $content -replace 'glyph_ids = kern_pair_glyph_ids,', "glyph_ids = $($varPrefix)_kern_pair_glyph_ids,"
$content = $content -replace 'values = kern_pair_values,', "values = $($varPrefix)_kern_pair_values,"

# Update unicode_list references (handle all numbered lists)
$content = $content -replace 'unicode_list = unicode_list_(\d+),', "unicode_list = $($varPrefix)_unicode_list_`$1,"

# Update glyph_bitmap reference
$content = $content -replace 'glyph_bitmap = glyph_bitmap,', "glyph_bitmap = $($varPrefix)_glyph_bitmap,"

# 5. Remove ALL version conditionals around cache
$cacheReplacement = '$1' + "`nstatic lv_font_fmt_txt_glyph_cache_t $($varPrefix)_cache;"
$content = $content -replace '#if LVGL_VERSION_MAJOR == 8\s*\n(/\*Store all the custom data of the font\*/)\s*\nstatic\s+lv_font_fmt_txt_glyph_cache_t\s+cache;\s*\n#endif', $cacheReplacement

# 6. Remove version conditionals from cache reference in font_dsc
$content = $content -replace '#if LVGL_VERSION_MAJOR == 8\s*\n\s*\.cache = &cache\s*\n#endif', "    .cache = &$($varPrefix)_cache"

# 7. Remove complex font descriptor version conditionals
$content = $content -replace 'static const lv_font_fmt_txt_dsc_t font_dsc = \{\s*\n#else\s*\nstatic lv_font_fmt_txt_dsc_t font_dsc = \{\s*\n#endif', "static const lv_font_fmt_txt_dsc_t $($varPrefix)_font_dsc = {"

# 8. Remove complex font struct version conditionals
$content = $content -replace 'const lv_font_t ([a-zA-Z_][a-zA-Z0-9_]*) = \{\s*\n#else\s*\nlv_font_t ([a-zA-Z_][a-zA-Z0-9_]*) = \{\s*\n#endif', 'const lv_font_t $1 = {'

# 9. Remove any remaining #else and #endif orphans
$content = $content -replace '\n#else\s*\n.*?\n#endif', ''

# 10. Remove ALL LVGL version conditionals
$content = $content -replace '#if LVGL_VERSION_MAJOR >= 8\s*\n', ''
$content = $content -replace '#if LV_VERSION_CHECK\([^)]+\)\s*[^#]*\n', ''
$content = $content -replace '#endif[^\n]*\n', ''

# 11. Remove LVGL 9-specific fields
$content = $content -replace '\s*\.static_bitmap = 0,', ''
$content = $content -replace '\s*\.user_data = NULL,', ''
$content = $content -replace '\s*\.fallback = NULL,', ''

# 12. Fix escaped newline characters
$content = $content -replace '`n', "`n"

# 13. Ensure proper LVGL 8 fields are present
if ($content -notmatch '\.subpx = LV_FONT_SUBPX_NONE') {
    $subpxReplacement = '$1' + "`n    .subpx = LV_FONT_SUBPX_NONE,"
    $content = $content -replace '(\.base_line = [^,]+,)', $subpxReplacement
}

if ($content -notmatch '\.underline_position') {
    $underlineReplacement = '$1' + "`n    .underline_position = -1,`n    .underline_thickness = 1,"
    $content = $content -replace '(\.subpx = LV_FONT_SUBPX_NONE,)', $underlineReplacement
}

# 14. Clean up extra whitespace
$content = $content -replace '\n\s*\n\s*\n', "`n`n"
$content = $content -replace '\s+\n', "`n"

# 15. Final cleanup and add header guards
$content = $content -replace '#if [A-Z_]+ == \d+\s*\n', ''
$content = $content + '#endif'

# Add proper header with unique include guard
$headerGuard = $fontName.ToUpper() -replace '[^A-Z0-9_]', '_'
$content = "`n #if $headerGuard`n`n" + $content
$content = "`n #endif`n" + $content
$content = "`n #define $headerGuard 1" + $content
$content = "`n #ifndef $headerGuard" + $content
$content = "`n #endif`n" + $content
$content = "`n     #include `"../lvgl-8.3.11/lvgl.h`"" + $content
$content = "`n #else" + $content
$content = "`n     #include `"lvgl.h`"" + $content
$content = "`n #ifdef LV_LVGL_H_INCLUDE_SIMPLE" + $content
$content = "`n #endif`n" + $content
$content = "`n     #endif" + $content
$content = "`n         #endif" + $content
$content = "`n             #define LV_LVGL_H_INCLUDE_SIMPLE" + $content
$content = "`n         #ifndef LV_LVGL_H_INCLUDE_SIMPLE" + $content
$content = "`n    #if __has_include(`"lvgl.h`")" + $content
$content = "`n#ifdef __has_include`n" + $content
$content = $beforeHeader + $content
$content = $content -replace '`n', "`n"
$content = $content -replace '(LVGL_VERSION_MAJOR == 6 && LVGL_VERSION_MINOR == 0)', "" 
$content = $content -replace '#if !\(\)', ""
$content = $content -replace '\(\)', ""

# Write the output file
try {
    Set-Content -Path $OutputFile -Value $content -Encoding UTF8
    Write-Host "Conversion completed successfully!" -ForegroundColor Green
    Write-Host "Output saved to: $OutputFile" -ForegroundColor Green
    
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
    
    # Check for unique variable names
    if ($outputContent -match "$($varPrefix)_glyph_bitmap") {
        Write-Host "Variable prefixing successful - $varPrefix`_* variables created" -ForegroundColor Green
    } else {
        Write-Warning "Variable prefixing may have failed - manual review recommended"
    }
}
catch {
    Write-Error "Failed to write output file: $_"
    exit 1
}

Write-Host "`nConversion Summary:" -ForegroundColor Cyan
Write-Host "- Removed LVGL 9-specific version conditionals"
Write-Host "- Fixed font descriptor structure for LVGL 8"
Write-Host "- Prefixed all static variables with: $varPrefix`_"
Write-Host "- Ensured cache is properly declared and referenced"
Write-Host "- Removed unsupported LVGL 9 fields, fixed header"
Write-Host "- Fixed include paths and structure compatibility"
Write-Host "- Cleaned up escaped characters and formatting"
Write-Host "`nWarning:" -ForegroundColor Red
Write-Host "- Check that the lvgl.h pointer is correct for your script" -ForegroundColor Yellow
Write-Host "- Default path: '../lvgl-8.3.11/lvgl.h'" -ForegroundColor Yellow
Write-Host "- All fonts now use unique variable names to prevent conflicts" -ForegroundColor Green
