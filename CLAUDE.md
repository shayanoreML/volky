SUPER-PROMPT — Build Volcy (iPhone-first, on-device ML) + Web Companion (view-only)
Mission

Hey Claude, please help me build this application! Details below:

Volcy, an iPhone app that delivers millimeter-accurate skin analytics from in-app scans: per-lesion diameter (mm), redness (Δa*), elevation (mm), volume proxy (mm³), healing rate (%/day), region stats, and regimen A/B. All inference on device. Sync metrics only (no photos/depth) to a web companion dashboard. Production-grade quality, privacy-first.

Non-negotiables (design constraints)

iPhone is the source of truth: capture only via in-app camera (no photo uploads anywhere).

On-device ML: Core ML inference; never send images or depth to servers.

Metrics-only sync for web dashboard (charts, trends, regimen logs).

Strict QC before capture (pose, distance, glare, white balance, blur).

No diagnosis; wellness tracking language only.

Privacy by default; local storage for media, export/delete controls.

Platforms & Tech

iOS app: Swift 5.9+, SwiftUI, Combine, ARKit (TrueDepth/LiDAR), AVFoundation, Vision, Core Image, Core ML, Accelerate/BNNS, PDFKit, StoreKit 2, BackgroundTasks, App Intents.

Local data: Core Data (SQLite) for scans/lesions/regimen + FileManager for media (HEIC, depth).

Sync backend (metrics only): Prefer CloudKit (private DB; simplest, privacy-first). Alternative (if cross-platform auth needed): Supabase/Postgres or Firebase, but still metrics-only.

Web companion (view-only): Next.js + Tailwind + shadcn/ui on Vercel. Auth via Sign in with Apple (Web). Reads metrics from CloudKit JS or your API.

CI/CD: Xcode Cloud or fastlane; TestFlight; App Store Connect; code signing auto-managed.

Observability: os_log + MetricKit, XCTest + XCUITests, crash reports (Apple), optional privacy-preserving analytics.

Project structure (monorepo)
volcy/
  ios/
    VolcyApp.xcodeproj
    Sources/
      App/                // App entry, DI container
      DesignSystem/       // Colors, typography, components
      Capture/            // ARKit/AVFoundation + QC gates
      DepthScale/         // Intrinsics, depth→mm, calibration dot fallback
      SegmentationML/     // CoreML model loader + inference
      ReID/               // UV mapping + lesion matching (Hungarian)
      Metrics/            // Diameter, elevation, Δa*, volume, healing rate
      Regimen/            // Routine logs, A/B scaffolding
      Persistence/        // Core Data stack & models
      Sync/               // CloudKit or API client for metrics-only
      Reports/            // PDF export
      Paywall/            // StoreKit 2
      Settings/           // Privacy, data export/delete
    Resources/            // Strings, icons, localized copy
    Models/ML/            // .mlpackage, versioned
    Tests/                // Unit/UI tests
  web/
    app/                  // Next.js routes (marketing + dashboard)
    components/           // shadcn/ui
    lib/                  // CloudKit JS or API client
    styles/               // Tailwind
  ml/                     // Training notebooks, conversion scripts, model cards
  ops/                    // fastlane, build scripts, release notes
  docs/                   // Architecture, privacy, science page

iOS app — feature set & acceptance criteria
Capture & QC (Capture/)

Front TrueDepth (daily scans) + Rear Pro mode (hi-detail with Watch shutter).

Live pose/distance gate (target 28cm ±1cm; yaw/pitch/roll ≤ 3° of baseline).

Lighting QC: glare %, white-balance ΔE vs baseline, histogram clipping, blur (variance of Laplacian).

Block shutter unless QC passes; provide hints (e.g., “a touch closer, reduce glare”).

Acceptance: ≥90% scans pass QC in controlled light; end-to-results < 3s on A17.

Depth & Scale (DepthScale/)

Prefer ARKit depth → mm using intrinsics 
𝑓
𝑥
,
𝑓
𝑦
f
x
	​

,f
y
	​

 + Z.

Fallback: Calibration dot (10mm sticker): detect circle → px/mm → scale.

Compute per-scan scale confidence; store with metrics.

Acceptance: diameter repeatability ≤ ±0.6mm (depth/dot) at 25–30cm.

Segmentation (SegmentationML/)

On-device UNet-lite (MobileNetV3-Small backbone) at 512², FP16, <8MB.

Classes: papule, pustule, nodule/cyst, open/closed comedone, PIH/PIE, scar, mole (mask-out).

Post-proc: connected components → morphological smooth.

Acceptance: mIoU ≥ 0.65 on held-out diverse tones; on-device inference ≤ 500ms.

Re-identification (ReID/)

Build per-user canonical UV face map from ARKit mesh at onboarding.

For each lesion: (uv_x, uv_y, class, size, small embedding from 64×64 crop).

Match consecutive scans via Hungarian with cost = 0.6·UV distance + 0.3·appearance + 0.1·class penalty.

Allow user naming (e.g., “Volcy”).

Acceptance: ≥90% weekly continuity for persistent lesions under QC.

Metrics Engine (Metrics/)

Diameter (mm): max Feret + equivalent diameter (depth-scaled).

Elevation (mm): local plane fit around boundary; height map 
𝑍
𝑝
𝑙
𝑎
𝑛
𝑒
−
𝑍
𝑙
𝑒
𝑠
𝑖
𝑜
𝑛
Z
p
	​

lane−Z
l
	​

esion.

Volume proxy (mm³): 
∑
ℎ
⋅
𝑎
𝑟
𝑒
𝑎
𝑝
𝑥
∑h⋅area
px
	​

.

Redness Δa*: RGB→CIELAB; specular mask; mean a* (lesion) − mean a* (skin ring).

Healing rate: % change/day (robust slope; 7–14 day window).

Region summaries: T-zone/U-zone counts, inflamed area (mm²).

Acceptance: elevation repeatability ≤ ±0.5mm (depth) / ≤ ±1.0mm (stereo fallback); redness repeatability Δa* ≤ ±2.0.

Regimen & A/B (Regimen/)

Log products & changes; compare windows with non-parametric effect size (e.g., Cliff’s delta) + clear caveats.

“Proof your routine” charts; no medical claims.

Persistence (Persistence/)

Core Data entities:

UserProfile(id, skinType, fitzpatrick, createdAt)

Scan(id, ts, mode, pose, distanceMM, qcFlags, imagePath, depthPath, intrinsics, lightingStats)

Lesion(id, stableId, scanId, class, name?, uvX, uvY, bbox, maskPath, diameterMM, elevationMM, volumeMM3, erythemaAstar, deltaE, confidence)

RegionSummary(scanId, region, counts, inflamedAreaMM2, meanDiameter, meanAstar, ...)

RegimenEvent(id, userId, ts, products[], notes)

Media stays local; paths stored in Core Data.

Export/Delete user data from Settings.

Reports/Export (Reports/)

Derm PDF for 7/30/90 days: per-lesion charts, region trends, QC summary.

Share sheet export; redaction options (no names/faces).

Paywall (Paywall/)

StoreKit 2: volcy.pro.monthly, volcy.pro.yearly.

Free: unlimited scans, Clarity Score, 1 region.

Pro: full face, elevation/volume, regimen A/B, PDF export, multi-profile.

Feature gates handled locally; server mirror optional.

Settings & Privacy (Settings/)

Data policy summary; on-device processing statement.

iCloud backup toggle (encrypted).

Delete/export all data.

Web companion (view-only, no uploads)

Routes:

/ marketing + email waitlist

/app authenticated dashboard (metrics charts, regimen logs, export PDFs)

/privacy, /science

Auth: Sign in with Apple (Web). Server verifies App Store sub (optional).

Data: Read metrics only; never accept files.

Charts: line charts (Clarity Score, Δa*, diameter), region heatmap, regimen overlay.

CTA: “Open on iPhone to scan” deep-link (volcy://scan) or QR code.

Sync & backend options (pick one)
Option A (recommended): CloudKit (Private DB)

iOS writes metrics records; web reads via CloudKit JS after Apple auth.

No servers to run; Apple-native privacy; automatic encryption.

Option B: Lightweight API (Supabase/Firebase)

iOS posts metrics JSON; web reads via REST; App Store Server Notifications to mirror Pro status. Keep no images.

Metrics record example:

{
  "user_id":"...","scan_ts":"2025-09-30T15:10:00Z","clarity_score":78,
  "qc":{"distance_mm":285,"pose_ok":true,"lighting_ok":true},
  "region_summary":{"t_zone":{"inflamed_area_mm2":123.4,"count":5}},
  "lesions":[
    {"stable_id":"L-abc","uv":[0.42,0.31],"class":"papule",
     "diameter_mm":2.8,"elevation_mm":0.6,"delta_a":5.2,"confidence":0.86}
  ]
}

ML pipeline (ml/)

Dataset: 8–12k annotated crops, diverse Fitzpatrick, balanced classes.

Augment: ±20% brightness/contrast, hue ±5°, slight blur, synthetic specular, flips, micro-pose.

Model: MobileNetV3-Small UNet (512²), Dice+Focal loss, AdamW 3e-4, cosine decay, 50–100 epochs.

ReID embedding: 64-D conv head, triplet loss (optional v1).

Export: PyTorch → ONNX → coremltools FP16 .mlpackage.

Versioning: DVC or Git-LFS; model_card.md with metrics/bias notes.

Calibration: color correction matrix learned from skin swatches; specular mask pre-step.

Design system (air-light “Breeze Clinical”)

Palette: Cloud #F7FAFC (bg), Mist #ECF2F7 (cards), Graphite #111827 (text), Mint #69E3C6 (primary), Sky #6AB7FF (secondary), Ash #E2E8F0 (hairline).

Type: SF Pro (UI), Space Grotesk (H), JetBrains Mono (numbers).

Tokens JSON:

{"color":{"canvas":"#F7FAFC","surface":"#ECF2F7","textPri":"#111827","textSec":"#374151","mint":"#69E3C6","sky":"#6AB7FF","hairline":"#E2E8F0"},
 "radius":{"card":14,"button":12,"pill":999},
 "space":[4,8,12,16,24,32,48],
 "shadow":{"card":"0 8px 24px rgba(0,0,0,0.08)"}}


Components: cards w/ 14px radius, 1.5–2px chart strokes, rounded caps.

Security & privacy hardening

No photo library pickers; capture-only.

Store images/depth locally only; metrics optionally synced.

Keychain for secrets; Secure Enclave where applicable.

Data export/delete endpoint; privacy nutrition labels; no 3rd-party trackers.

Copy guardrails (no diagnosis; “wellness tracking”).

Testing, performance, and QA

Unit tests: scale math, plane fit, Δa*, matcher, QC.

Snapshot tests: segmentation masks.

UI tests: capture flow, paywall, reports.

Performance: end-to-end analysis ≤ 2s on A17; model ≤ 500ms.

Field QA: 6 lighting scenarios; multiple skin tones; glasses/makeup.

Acceptance targets (repeatability):

Diameter ≤ ±0.6mm; Elevation ≤ ±0.5mm (depth); Redness Δa* ≤ ±2.0.

CI/CD & release

Branches: main (release), develop (beta), feature/*.

Automation: fastlane (build, bump, screenshots), TestFlight β cohorts, release notes.

App Store: Privacy Manifest, data nutrition, screenshots (light/dark), keywords, localized copy.

Subscriptions: StoreKit 2; server-side validation optional; price localization.

Analytics & telemetry (privacy-respecting)

Local by default. Optional opt-in: aggregate QC pass rate, average scan time, crashes via Apple. No per-image telemetry.

Naming & copy (volcano-free, airy)

Brand: Volcy

Topline: “Quantified skin progress, privately on your iPhone.”

Features: Clarity Score, Clear Streak, Texture Map, Redness Delta (Δa*), Routine Journal.

Tone: precise, supportive; “Measure. Don’t guess.”

Delivery checklist (definition of done)

iOS app compiles on iOS 17+; capture→results under 3s; QC gates working.

On-device ML model integrated; metrics calculated; per-lesion tracking stable.

Core Data persists scans/lesions; media local; export/delete works.

StoreKit paywall functional; Pro features gated; receipts validated.

CloudKit (or API) syncs metrics only; web dashboard renders charts.

PDF export renders correctly; share sheet works.

Privacy pages, App Privacy Manifest, nutrition labels completed.

Tests (unit/UI/perf) pass in CI; TestFlight build shipped to cohort.

Initial task plan (agent should generate code for each)

Scaffold project + DI + design tokens; build CaptureView with ARKit gates.

Implement DepthScale (intrinsics, depth→mm, calibration dot).

Ship placeholder segmentation (classical threshold/circle) → swap to Core ML when ready.

Build Metrics (diameter, Δa*, elevation/volume) with confidence bands.

Implement ReID (UV mapping + Hungarian matcher; naming).

Core Data schema + migrations + Settings export/delete.

Reports (PDFKit) + Paywall (StoreKit 2).

Sync (CloudKit metrics only) + Web dashboard (Next.js) read.

Tests + fastlane lanes; TestFlight config; release notes scaffolding.

Guardrails & edge cases to handle

Makeup/beard/specular glare → QC reject with corrective hints.

Missing depth → calibration dot or stereo fallback (rear camera two shots).

Multiple profiles on one device; regional locales; accessibility (Dynamic Type, VoiceOver labels).

Social sharing opt-in with crop/blur; no public leaderboards (use personal bests/streaks).