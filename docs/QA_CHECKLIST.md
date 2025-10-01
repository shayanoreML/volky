# Volcy QA Checklist

Complete testing checklist before launch.

## Device Requirements

- ✅ iPhone 14 Pro or later (TrueDepth)
- ✅ iPhone 15 Pro or later (LiDAR recommended)
- ✅ iOS 17.0+

## Phase 17: QA & Field Testing

### 1. Capture System

#### ARKit & Camera
- [ ] Front camera (TrueDepth) launches correctly
- [ ] Rear camera (LiDAR) launches correctly (Pro models)
- [ ] Camera permission prompt displays
- [ ] Denial of permission shows appropriate error
- [ ] ARKit session starts within 2 seconds
- [ ] Live preview displays correctly
- [ ] No crashes on session start/stop

#### QC Gates
- [ ] **Pose QC**: Responds to head rotation (yaw/pitch/roll)
- [ ] **Distance QC**: Updates as user moves closer/farther
- [ ] **Lighting QC**: Detects glare in bright light
- [ ] **Lighting QC**: Detects underexposure in dim light
- [ ] **Blur QC**: Detects motion blur
- [ ] All 4 indicators update in real-time (<16ms)
- [ ] Checkmarks appear when gates pass
- [ ] Feedback banner updates with correct hints

#### Lighting Scenarios (Test All 6)
1. [ ] Indoor artificial light (overhead)
2. [ ] Natural daylight (window)
3. [ ] Outdoor direct sun
4. [ ] Dim light (evening)
5. [ ] Mixed lighting (window + lamp)
6. [ ] Bathroom lighting (mirror + overhead)

#### Shutter & Capture
- [ ] Shutter button disabled when QC fails
- [ ] Shutter button turns mint when all QC passes
- [ ] Capture completes in <1 second
- [ ] Processing indicator shows during capture
- [ ] Success message displays on completion
- [ ] Captured frame includes valid depth map
- [ ] Image quality is sharp and well-exposed

### 2. Depth & Metrics

#### Depth Conversion
- [ ] Depth map converts to millimeters correctly
- [ ] Intrinsics-based conversion works (preferred)
- [ ] Calibration dot fallback works (test with 10mm sticker)
- [ ] Depth values in expected range (200-400mm)
- [ ] Confidence scores calculated correctly

#### Metrics Accuracy (Repeatability Tests)
- [ ] Diameter: ≤±0.6mm across 5 scans
- [ ] Elevation: ≤±0.5mm across 5 scans (TrueDepth)
- [ ] Elevation: ≤±1.0mm across 5 scans (stereo fallback)
- [ ] Redness Δa*: ≤±2.0 across 5 scans
- [ ] Test on reference object (coin, calibration target)
- [ ] Test on skin lesion simulator

### 3. Segmentation

#### Classical Placeholder
- [ ] Detects red/inflamed lesions
- [ ] Handles various skin tones correctly
- [ ] No false positives on makeup
- [ ] No false positives on moles
- [ ] Runs in <100ms

#### Core ML (When Available)
- [ ] Model loads successfully
- [ ] Inference completes in ≤500ms
- [ ] mIoU ≥ 0.65 on test set
- [ ] No crashes on inference
- [ ] Works across all Fitzpatrick types

### 4. Re-Identification

- [ ] UV face map generated on first scan
- [ ] Lesions matched across consecutive scans
- [ ] ≥90% weekly continuity for persistent lesions
- [ ] New lesions detected correctly
- [ ] Lost lesions marked appropriately
- [ ] User can name lesions (e.g., "Volcy")

### 5. Performance

- [ ] End-to-end scan: <3 seconds on A17
- [ ] End-to-end scan: <5 seconds on A15
- [ ] Memory usage: <500MB during scan
- [ ] No memory leaks after 10 scans
- [ ] Battery drain: <5% per scan
- [ ] App stays responsive throughout
- [ ] No frame drops in camera preview

### 6. Persistence

- [ ] Scans save to Core Data correctly
- [ ] Lesions save with metrics
- [ ] Region summaries calculated
- [ ] Export all data as JSON works
- [ ] Delete all data works (irreversible!)
- [ ] iCloud backup toggle works

### 7. Regimen & A/B

- [ ] Log regimen event with products
- [ ] Compare two time windows
- [ ] Cliff's delta calculated correctly
- [ ] Effect size interpretation makes sense
- [ ] Charts display trends clearly

### 8. Reports & PDF

- [ ] 7-day report generates correctly
- [ ] 30-day report generates correctly
- [ ] 90-day report generates correctly
- [ ] Charts render properly in PDF
- [ ] Share sheet opens with PDF
- [ ] PDF opens in Files/Mail/etc.

### 9. Paywall & StoreKit

- [ ] Product IDs load from App Store
- [ ] Purchase flow works (monthly)
- [ ] Purchase flow works (yearly)
- [ ] Restore purchases works
- [ ] Pro features unlock after purchase
- [ ] Free features remain accessible
- [ ] Transaction receipt validation works

### 10. Settings & Privacy

- [ ] Toggle iCloud backup
- [ ] Toggle notifications (with permission)
- [ ] Toggle scan reminders
- [ ] Export data produces valid JSON
- [ ] Delete all data confirmation works
- [ ] Privacy policy displays
- [ ] About section shows correct version

### 11. CloudKit Sync

- [ ] Metrics sync to CloudKit
- [ ] No photos/depth uploaded (verify!)
- [ ] Sync completes in <10 seconds
- [ ] Sync retries on failure
- [ ] Web dashboard shows synced data
- [ ] Offline mode handles gracefully

### 12. Web Dashboard

- [ ] Sign in with Apple works
- [ ] Dashboard loads metrics
- [ ] Charts display correctly
- [ ] Responsive on mobile browsers
- [ ] "Open on iPhone" CTA works
- [ ] Sign out works

### 13. Edge Cases

#### Challenging Conditions
- [ ] Glasses (reflection/occlusion)
- [ ] Beard/facial hair
- [ ] Makeup (foundation, concealer)
- [ ] Scarring
- [ ] Very dark skin (Fitzpatrick VI)
- [ ] Very light skin (Fitzpatrick I)
- [ ] Oily/shiny skin (specular highlights)
- [ ] Dry/flaky skin

#### Error Handling
- [ ] No depth data available
- [ ] ARKit tracking lost
- [ ] Low lighting
- [ ] Camera covered
- [ ] Device overheating
- [ ] Low battery during scan
- [ ] Network unavailable (sync)
- [ ] iCloud not signed in

### 14. Accessibility

- [ ] VoiceOver labels present
- [ ] Dynamic Type supported
- [ ] Contrast ratios meet WCAG AA
- [ ] Touch targets ≥44pt
- [ ] All buttons accessible

### 15. Internationalization

- [ ] English (US) - Primary
- [ ] Date formats localized
- [ ] Number formats localized (mm, %)
- [ ] Currency for subscriptions

### 16. App Store Readiness

- [ ] App icon (1024×1024)
- [ ] Launch screen
- [ ] Screenshots (all device sizes)
- [ ] Privacy nutrition labels complete
- [ ] App privacy manifest included
- [ ] Keywords optimized
- [ ] Description compelling
- [ ] Age rating appropriate
- [ ] Contact info correct

### 17. Crash & Error Reporting

- [ ] Test deliberate crash
- [ ] Crash reports received in Xcode Organizer
- [ ] MetricKit data captured
- [ ] No PII in crash logs

## Acceptance Criteria (Final Check)

- [ ] QC pass rate ≥90% in controlled lighting
- [ ] End-to-end time <3s on A17
- [ ] Diameter repeatability ≤±0.6mm
- [ ] Elevation repeatability ≤±0.5mm (depth)
- [ ] Redness repeatability Δa* ≤±2.0
- [ ] ML inference ≤500ms (when model integrated)
- [ ] Re-ID weekly continuity ≥90%

## Sign-Off

- [ ] Engineering Lead
- [ ] QA Lead
- [ ] Product Manager
- [ ] Designer
- [ ] Privacy Officer

---

**Once all items checked, ready for TestFlight beta!** 🚀
