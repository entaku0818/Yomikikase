# Release Checklist v0.11.0 - Text Highlighting Feature

## ✅ Completed Tasks

### Version Management
- [x] Version updated: 0.10.1 → 0.11.0
- [x] project.pbxproj MARKETING_VERSION updated
- [x] Git commit created with comprehensive changes
- [x] Git tag v0.11.0 created

### Documentation
- [x] CHANGELOG.md created
- [x] RELEASE_NOTES_v0.11.0.md created
- [x] App Store release notes updated (Japanese & English)
- [x] App Store descriptions updated with new features

### Code Implementation
- [x] Text highlighting functionality implemented
- [x] PDF highlighting functionality implemented
- [x] UITextView-based precise highlighting
- [x] TCA state management integration
- [x] Build verified successful

## 📋 Remaining Pre-Release Tasks

### 1. iPad Screenshots (Required)
- [ ] **Take iPad Pro 12.9" screenshots (2048x2732 pixels)**
  - [ ] Main screen with text highlighting demonstration
  - [ ] PDF reader showing highlighting feature
  - [ ] Settings/features overview screen
- [ ] **Add screenshots to fastlane directories:**
  - [ ] `fastlane/screenshots/en-US/0_APP_IPAD_PRO_129_0.jpg`
  - [ ] `fastlane/screenshots/en-US/1_APP_IPAD_PRO_129_1.jpg`
  - [ ] `fastlane/screenshots/en-US/2_APP_IPAD_PRO_129_2.jpg`
  - [ ] Japanese versions in `fastlane/screenshots/ja/`

### 2. Final Testing
- [ ] **Release build testing**
  ```bash
  xcodebuild -project VoiceYourText.xcodeproj -scheme VoiceYourText -configuration Release
  ```
- [ ] **Feature verification:**
  - [ ] Text highlighting works during speech synthesis
  - [ ] PDF highlighting functions correctly
  - [ ] Automatic scrolling to highlighted text
  - [ ] All existing features still work (regression testing)
- [ ] **Device testing:**
  - [ ] iPhone testing (multiple sizes)
  - [ ] iPad testing (verify UI scaling)

### 3. App Store Preparation
- [ ] **Archive creation**
  - [ ] Create archive in Xcode (Product → Archive)
  - [ ] Verify archive builds successfully
  - [ ] Upload to App Store Connect

- [ ] **Metadata upload**
  ```bash
  cd /path/to/VoiceYourText
  bundle exec fastlane ios upload_metadata
  ```

### 4. App Store Connect Configuration
- [ ] **TestFlight Setup**
  - [ ] Internal testing group setup
  - [ ] External testing group (if needed)
  - [ ] Beta app review (if using external testing)

- [ ] **App Store Listing**
  - [ ] Verify all metadata is correct
  - [ ] Check screenshots are properly uploaded
  - [ ] Verify app description highlights new features
  - [ ] Confirm pricing and availability settings

- [ ] **Review Information**
  - [ ] Update reviewer notes if needed
  - [ ] Verify contact information
  - [ ] Add any special instructions for testing highlight feature

### 5. Pre-Submission Review
- [ ] **App Review Guidelines Check**
  - [ ] No rejected content
  - [ ] Privacy policy updated if needed
  - [ ] In-app purchases working correctly
  - [ ] Subscription features functional

- [ ] **Final Quality Assurance**
  - [ ] App launches without crashes
  - [ ] All features work as expected
  - [ ] UI looks good on all supported devices
  - [ ] Performance is acceptable

### 6. Submission
- [ ] **Submit for Review**
  - [ ] Select build for release
  - [ ] Set release method (manual/automatic)
  - [ ] Submit for App Review

## 📞 Emergency Contacts & Resources

### Important Commands
```bash
# Update metadata only (no binary)
bundle exec fastlane ios upload_metadata

# Check build status
xcodebuild -list

# View git tags
git tag --list

# Check current version
grep MARKETING_VERSION VoiceYourText.xcodeproj/project.pbxproj
```

### Required Files for Screenshots
- Resolution: 2048x2732 (iPad Pro 12.9")
- Format: JPG
- Content: App demonstrating text highlighting feature

### Timeline Estimate
- iPad Screenshots: 1-2 hours
- Testing: 2-3 hours  
- App Store Upload: 30 minutes
- Review Process: 24-48 hours (Apple)

## 🚨 Critical Notes

1. **Text Highlighting Feature**: Ensure this is prominently demonstrated in screenshots
2. **iPad Support**: App supports iPad (TARGETED_DEVICE_FAMILY = "1,2")
3. **Backward Compatibility**: All existing features must continue working
4. **Performance**: Highlighting should not impact app performance significantly

---

**Next Action Required**: Take iPad screenshots and replace placeholder files in fastlane/screenshots/ directories.