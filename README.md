# Volcy

**Quantified skin progress, privately on your iPhone.**

Volcy delivers millimeter-accurate skin analytics from in-app scans: per-lesion diameter (mm), redness (Δa*), elevation (mm), volume proxy (mm³), healing rate (%/day), region stats, and regimen A/B testing. All inference happens on-device. Sync metrics only (no photos/depth) to a web companion dashboard.

## Project Structure

```
volcy/
├── ios/                    # iOS app (Swift/SwiftUI)
│   ├── Sources/
│   │   ├── App/           # App entry point, DI container
│   │   ├── DesignSystem/  # Breeze Clinical design tokens
│   │   ├── Capture/       # ARKit/AVFoundation + QC gates
│   │   ├── DepthScale/    # Depth-to-mm conversion
│   │   ├── SegmentationML/# Core ML inference
│   │   ├── ReID/          # Lesion re-identification
│   │   ├── Metrics/       # Metrics calculation
│   │   ├── Regimen/       # Routine tracking & A/B
│   │   ├── Persistence/   # Core Data
│   │   ├── Sync/          # CloudKit metrics sync
│   │   ├── Reports/       # PDF export
│   │   ├── Paywall/       # StoreKit 2
│   │   └── Settings/      # Privacy & data controls
│   ├── Resources/         # Assets, strings, Info.plist
│   ├── Models/ML/         # .mlpackage Core ML models
│   └── Tests/             # Unit/UI/Performance tests
├── web/                   # Next.js web companion (view-only)
├── ml/                    # ML training & conversion scripts
├── ops/                   # fastlane, CI/CD scripts
└── docs/                  # Architecture, privacy, science
```

## Tech Stack

### iOS
- **Swift 5.9+**, SwiftUI, Combine
- **ARKit** (TrueDepth/LiDAR), **AVFoundation**
- **Core ML**, **Vision**, **Accelerate**
- **Core Data** (local persistence)
- **CloudKit** (metrics-only sync)
- **StoreKit 2** (subscriptions)

### Web
- **Next.js** + **Tailwind** + **shadcn/ui**
- **Vercel** deployment
- **CloudKit JS** (read-only metrics)

### ML
- **PyTorch** → **Core ML**
- MobileNetV3-Small UNet (<8MB, FP16)

## Design System: Breeze Clinical

Air-light, precise, supportive aesthetic.

**Colors:**
- Canvas: `#F7FAFC` (Cloud)
- Surface: `#ECF2F7` (Mist)
- Text: `#111827` (Graphite)
- Accent: `#69E3C6` (Mint)
- Secondary: `#6AB7FF` (Sky)
- Hairline: `#E2E8F0` (Ash)

**Typography:**
- UI: SF Pro
- Headings: Space Grotesk
- Numbers: JetBrains Mono

## Features

### Core Capabilities
- ✅ **Capture & QC**: Live pose/distance/lighting gates (ARKit)
- ✅ **Depth Scale**: Intrinsics-based or 10mm calibration dot
- ✅ **Segmentation**: On-device ML (papule, pustule, nodule, etc.)
- ✅ **Re-ID**: UV face mapping + Hungarian matcher
- ✅ **Metrics**: Diameter, elevation, redness (Δa*), healing rate
- ✅ **Regimen**: Product logging + A/B comparison
- ✅ **Reports**: Derm-ready PDF export (7/30/90 days)
- ✅ **Privacy**: Local-first, metrics-only sync, export/delete

### Free Tier
- Unlimited scans
- Clarity Score
- 1 region tracking

### Pro Tier ($)
- Full face tracking
- Elevation & volume metrics
- Regimen A/B testing
- PDF export
- Multi-profile support

## Development Setup

### Prerequisites
- **Xcode 15+** (for iOS 17+)
- **Node.js 18+** (for web)
- **Python 3.10+** (for ML training)

### iOS App

```bash
cd ios
open Volcy.xcodeproj

# Or use Xcode Cloud / fastlane
bundle exec fastlane ios beta
```

### Web Dashboard

```bash
cd web
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

### ML Training

```bash
cd ml
pip install -r requirements.txt
jupyter notebook notebooks/train_segmentation.ipynb
```

## Testing

```bash
# iOS unit tests
xcodebuild test -scheme Volcy -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# iOS UI tests
xcodebuild test -scheme VolcyUITests -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Web tests
cd web && npm test
```

## Privacy & Security

- 🔒 **No photo uploads**: Capture-only via in-app camera
- 🔒 **On-device ML**: Core ML inference, never send images to servers
- 🔒 **Metrics-only sync**: CloudKit private DB (or API) syncs metrics, not media
- 🔒 **Local storage**: Images/depth stay on device
- 🔒 **Export/delete**: Full data portability and deletion
- 🔒 **No trackers**: Privacy-first, no 3rd-party analytics

## Acceptance Criteria

- **Diameter**: ≤ ±0.6mm repeatability
- **Elevation**: ≤ ±0.5mm (depth) / ±1.0mm (stereo)
- **Redness**: Δa* ≤ ±2.0
- **QC Pass Rate**: ≥90% in controlled light
- **Performance**: <3s end-to-end on A17
- **ML Inference**: ≤500ms on-device
- **Re-ID Continuity**: ≥90% weekly for persistent lesions

## Architecture

**Design Pattern**: Clean Architecture + MVVM + Dependency Injection

```
View (SwiftUI) → ViewModel → Service (Protocol) → Implementation
                                   ↓
                            DIContainer (shared)
```

**Data Flow**:
1. **Capture** → ARKit frame + QC gates
2. **DepthScale** → Depth-to-mm conversion
3. **Segmentation** → Core ML inference
4. **ReID** → UV mapping + Hungarian matcher
5. **Metrics** → Calculate per-lesion metrics
6. **Persistence** → Save to Core Data
7. **Sync** → Metrics-only to CloudKit
8. **Web** → Read-only dashboard

## License

Proprietary. All rights reserved.

## Contact

- **Website**: [volcy.app](https://volcy.app)
- **Email**: support@volcy.app
- **Privacy**: [volcy.app/privacy](https://volcy.app/privacy)

---

**Measure. Don't guess.** 📊
