# LVGL Font Converter

A PowerShell script that converts LVGL 9.3 font files to LVGL 8.3.11 format, removing version conditionals and fixing compatibility issues.

## What It Does

This script automates the conversion of LVGL font files from version 9.3 to 8.3.11 by:

- **Removing version conditionals** - Strips out `#if LVGL_VERSION_MAJOR >= 8` and similar checks
- **Fixing header structure** - Generates proper include paths for both `lvgl.h` and custom paths
- **Cleaning cache declarations** - Removes version-specific cache handling
- **Removing LVGL 9 fields** - Strips unsupported fields like `fallback`, `static_bitmap`, `user_data`
- **Ensuring LVGL 8 compatibility** - Adds required fields like `subpx`, `underline_position`, `underline_thickness`
- **Formatting cleanup** - Fixes escaped characters, extra whitespace, and malformed structures

## Usage

### Basic Usage
```powershell
.\convert.ps1 -InputFile "my_font.c"
```
This creates `my_font_lvgl8.c` in the same directory.

### Specify Output File
```powershell
.\convert.ps1 -InputFile "cursive.c" -OutputFile "fonts/cursive_converted.c"
```

## File Structure

The script generates files with this header structure:
```c
#ifdef __has_include
    #if __has_include("lvgl.h")
        #ifndef LV_LVGL_H_INCLUDE_SIMPLE
            #define LV_LVGL_H_INCLUDE_SIMPLE
        #endif
    #endif
#endif

#ifdef LV_LVGL_H_INCLUDE_SIMPLE
    #include "lvgl.h"
#else
    #include "../lvgl-8.3.11/lvgl.h"  // Adjust path as needed
#endif

#ifndef FONT_NAME
#define FONT_NAME 1
#endif

#if FONT_NAME
// Font data...
#endif /*#if FONT_NAME*/
```

## Integration

### 1. Create Header File
Create a corresponding `.h` file:
```c
#ifndef MY_FONT_H
#define MY_FONT_H

#include "lvgl.h"

extern const lv_font_t my_font;

#endif
```

### 2. Use in Code
```c
#include "my_font.h"

// Set font on a label
lv_obj_set_style_text_font(label, &my_font, 0);
```

### 3. Project Structure
```
your_project/
├── src/
│   └── main.c
├── fonts/
│   ├── my_font_lvgl8.c
│   └── my_font_lvgl8.h
└── lvgl-8.3.11/
    └── lvgl.h
```

## Common Issues Fixed

- **Escaped newlines** - Converts `\`n` artifacts to proper newlines
- **Version conditionals** - Removes `#if !(LVGL_VERSION_MAJOR == 6 && LVGL_VERSION_MINOR == 0)`
- **Orphaned directives** - Cleans up stray `#else` and `#endif` statements
- **Cache structure** - Ensures proper cache declaration for LVGL 8
- **Font struct** - Removes unsupported LVGL 9 fields

## Script Features

- **Validation** - Checks output for common conversion issues
- **Recommendations** - Suggests file naming and project structure
- **Error handling** - Reports conversion problems and file issues
- **Flexible paths** - Handles both relative and absolute file paths

## Limitations

- Designed specifically for LVGL 8.3.11 with custom include path
- May require manual review for heavily customized font files
- Does not modify font data or glyph information, only structure
- Assumes standard LVGL font file format

## Requirements

- PowerShell 5.0 or later
- LVGL 8.3.11 library
- Original LVGL 9.3 font files to convert

## Notes

The script is configured for a specific project structure with LVGL located at `../lvgl-8.3.11/`. Modify the include path in the script if your structure differs.
