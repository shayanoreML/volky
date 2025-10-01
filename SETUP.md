# Volcy Setup Guide

This guide will help you get Volcy running on your development machine.

## Prerequisites

### Required
- **macOS 14+** (for iOS development)
- **Xcode 15+** (iOS 17+ SDK)
- **Node.js 18+** and npm
- **Git**

### Optional
- **Python 3.10+** (for ML training)
- **fastlane** (for CI/CD)
- **iPhone with TrueDepth/LiDAR** (for real device testing)

## Project Structure

```
volcy/
├── ios/                    # iOS app (Swift/SwiftUI)
├── web/                    # Web dashboard (Next.js)
├── ml/                     # ML training scripts
├── ops/                    # CI/CD and automation
└── docs/                   # Documentation
```

## iOS Setup

### Step 1: Open Xcode Project

Since we're using a custom modular architecture, you'll need to create the Xcode project:

1. **Open Xcode**
2. **Create New Project**:
   - Choose "App" template
   - Product Name: `Volcy`
   - Team: Your Apple Developer account
   - Organization Identifier: `com.volcy` (or your own)
   - Interface: SwiftUI
   - Language: Swift
   - Storage: Core Data
   - Include Tests: Yes

3. **Configure Project Settings**:
   - Deployment Target: iOS 17.0
   - Bundle Identifier: `com.volcy.app`
   - Capabilities:
     - ✅ ARKit
     - ✅ Camera
     - ✅ Push Notifications
     - ✅ Background Modes (Remote notifications)
     - ✅ Sign in with Apple
     - ✅ CloudKit (Private Database)
     - ✅ In-App Purchase

4. **Replace Generated Files**:
   - Delete the auto-generated `ContentView.swift` and `VolcyApp.swift`
   - Add all files from `ios/Sources/` to your project
   - Add `ios/Resources/Info.plist` to project
   - Add `ios/Models/ML/` folder for Core ML models

5. **Add Frameworks**:
   All frameworks are built-in, no external dependencies needed:
   - ARKit
   - AVFoundation
   - Vision
   - CoreML
   - CoreImage
   - CoreData
   - CloudKit
   - StoreKit
   - PDFKit
   - Combine
   - SwiftUI

### Step 2: Configure Signing

1. Open Xcode project settings
2. Select "Volcy" target → "Signing & Capabilities"
3. Enable "Automatically manage signing"
4. Select your Team
5. Xcode will generate a Bundle ID and provisioning profile

### Step 3: Add Privacy Permissions

The `Info.plist` in `ios/Resources/` already includes required privacy strings:
- Camera Usage
- ARKit Usage
- Face ID Usage
- Photo Library Usage (for export)

### Step 4: Create Core Data Model

1. In Xcode, File → New → File → Data Model
2. Name it `Volcy.xcdatamodeld`
3. Add entities (refer to `ios/Sources/Persistence/CoreDataModels.swift` for schema):
   - UserProfile
   - Scan
   - Lesion
   - RegionSummary
   - RegimenEvent

### Step 5: Build & Run

```bash
# Build for simulator
xcodebuild -scheme Volcy -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Or: Press Cmd+R in Xcode
```

**Note**: ARKit and TrueDepth features require a physical device. For initial development, the app will gracefully handle simulator limitations.

## Web Setup

### Step 1: Install Dependencies

```bash
cd web
npm install
```

### Step 2: Configure Environment

Create `.env.local`:

```env
NEXT_PUBLIC_APP_URL=http://localhost:3000
NEXT_PUBLIC_CLOUDKIT_CONTAINER=iCloud.com.volcy.app
NEXT_PUBLIC_CLOUDKIT_ENVIRONMENT=development
```

### Step 3: Run Development Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

### Step 4: Build for Production

```bash
npm run build
npm start
```

## ML Setup (Optional)

### Step 1: Install Python Dependencies

```bash
cd ml
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### Step 2: Training Dependencies

Create `ml/requirements.txt`:

```
torch>=2.0.0
torchvision>=0.15.0
coremltools>=7.0
onnx>=1.14.0
numpy>=1.24.0
opencv-python>=4.8.0
pillow>=10.0.0
scikit-learn>=1.3.0
matplotlib>=3.7.0
jupyter>=1.0.0
tqdm>=4.65.0
```

### Step 3: Model Conversion

```bash
# Convert PyTorch → Core ML
python scripts/convert_to_coreml.py \
  --model path/to/model.pth \
  --output ios/Models/ML/segmentation_v1.mlpackage
```

## Testing

### iOS Tests

```bash
# Unit tests
xcodebuild test \
  -scheme Volcy \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:VolcyTests

# UI tests
xcodebuild test \
  -scheme Volcy \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:VolcyUITests
```

### Web Tests

```bash
cd web
npm test
```

## Deployment

### iOS (TestFlight)

1. **Archive Build**:
   - Product → Archive in Xcode
   - Distribute App → App Store Connect
   - Upload to TestFlight

2. **Using fastlane** (recommended):
   ```bash
   cd ops
   bundle install
   bundle exec fastlane ios beta
   ```

### Web (Vercel)

1. **Connect Repository**:
   - Go to [vercel.com](https://vercel.com)
   - Import Git repository
   - Framework: Next.js
   - Root Directory: `web/`

2. **Configure Environment Variables**:
   - Add production CloudKit settings
   - Add Apple Sign In credentials

3. **Deploy**:
   ```bash
   cd web
   vercel --prod
   ```

## CloudKit Setup

1. **Create CloudKit Container**:
   - Go to [CloudKit Console](https://icloud.developer.apple.com/dashboard)
   - Create new container: `iCloud.com.volcy.app`

2. **Define Schema** (Private Database):
   - Create record types matching Core Data entities
   - Metrics-only (no image/depth data)

3. **Enable CloudKit in Xcode**:
   - Target → Signing & Capabilities
   - Add CloudKit capability
   - Select container

## Troubleshooting

### iOS Build Errors

**Error**: "No such module 'ARKit'"
- **Solution**: Ensure Deployment Target is iOS 17.0+

**Error**: "Code signing failed"
- **Solution**: Check Team selection in project settings

**Error**: "Core Data model not found"
- **Solution**: Ensure `Volcy.xcdatamodeld` is added to target

### Web Build Errors

**Error**: "Module not found"
- **Solution**: Run `npm install` in `web/` directory

**Error**: "Tailwind styles not loading"
- **Solution**: Check `tailwind.config.js` paths

## Next Steps

1. ✅ **Phase 1 Complete**: Project scaffolded
2. 🔜 **Phase 2**: Implement ARKit capture with QC gates
3. 🔜 **Phase 3**: Depth-to-mm conversion
4. 🔜 **Phase 4**: Segmentation placeholder
5. 🔜 **Phase 5**: Metrics engine
6. ... (see CLAUDE.md for full roadmap)

## Resources

- [Apple ARKit Documentation](https://developer.apple.com/documentation/arkit)
- [Core ML Documentation](https://developer.apple.com/documentation/coreml)
- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [Next.js Documentation](https://nextjs.org/docs)
- [StoreKit 2 Guide](https://developer.apple.com/documentation/storekit)

## Support

For issues, questions, or contributions:
- Email: dev@volcy.app
- GitHub Issues: (when public)

---

**Ready to build Volcy!** 🚀
