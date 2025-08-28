# iPad Screenshots for App Store

## Required iPad Screenshot Sizes

### iPad Pro (6th generation) 12.9-inch
- **Size**: 2048 x 2732 pixels (Portrait) or 2732 x 2048 pixels (Landscape)
- **File name format**: `X_APP_IPAD_PRO_129_X.jpg` 

### iPad Pro (12.9-inch) (5th generation)
- **Size**: 2048 x 2732 pixels (Portrait) or 2732 x 2048 pixels (Landscape)
- **File name format**: `X_APP_IPAD_PRO_129_X.jpg`

### iPad Pro (11-inch) (4th generation)
- **Size**: 1668 x 2388 pixels (Portrait) or 2388 x 1668 pixels (Landscape)
- **File name format**: `X_APP_IPAD_PRO_11_X.jpg`

## Screenshot Requirements

### Content to Capture
1. **Main Screen with Text Highlighting**
   - Show the main text editor with highlighted text during speech synthesis
   - Demonstrate the yellow highlighting feature

2. **PDF Reader with Highlighting**
   - Display a PDF document with highlighted text during reading
   - Show the audio controls and highlighted content

3. **Settings/Features Overview**
   - Language settings
   - Voice customization options
   - Premium features overview

### File Naming Convention
- `0_APP_IPAD_PRO_129_0.jpg` - Main screen with text highlighting
- `1_APP_IPAD_PRO_129_1.jpg` - PDF reader with highlighting
- `2_APP_IPAD_PRO_129_2.jpg` - Settings/features overview

### For Japanese Locale (ja)
- Same naming convention in `fastlane/screenshots/ja/` directory
- Content should be in Japanese language

## Instructions for Taking Screenshots

1. **Use iPad Simulator or Physical iPad**
   ```bash
   # Open iPad Pro 12.9" simulator
   xcrun simctl list devices | grep "iPad Pro"
   open -a Simulator --args -CurrentDeviceUDID [DEVICE_UDID]
   ```

2. **Capture Screenshots**
   - Navigate to each screen in the app
   - Enable text highlighting feature
   - Take screenshots using Cmd+S in simulator or device screenshots

3. **Resize and Optimize**
   ```bash
   # Resize if needed (using ImageMagick)
   convert screenshot.png -resize 2048x2732 screenshot.jpg
   
   # Optimize file size
   jpegoptim --max=85 screenshot.jpg
   ```

4. **Place in Correct Directories**
   - English: `fastlane/screenshots/en-US/`
   - Japanese: `fastlane/screenshots/ja/`

## App Store Connect Upload

After adding screenshots, run:
```bash
bundle exec fastlane ios upload_metadata
```

This will upload all screenshots to App Store Connect automatically.