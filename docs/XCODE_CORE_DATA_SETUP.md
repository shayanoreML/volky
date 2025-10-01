# Xcode Core Data Setup Guide

**Complete step-by-step guide for creating the Volcy Core Data model in Xcode.**

## Step 1: Create Data Model File

1. In Xcode, select **File → New → File**
2. Select **Core Data → Data Model**
3. Name it: `Volcy` (it will create `Volcy.xcdatamodeld`)
4. Save in the project root

## Step 2: Create 5 Entities

Click **Add Entity** button (+) at the bottom and create these 5 entities:

### Entity 1: UserProfile

**Attributes:**
| Name | Type | Optional | Default | Indexed |
|------|------|----------|---------|---------|
| id | UUID | ❌ No | - | ✅ Yes |
| skinType | String | ✅ Yes | - | ❌ No |
| fitzpatrick | Integer 16 | ✅ Yes | - | ❌ No |
| createdAt | Date | ❌ No | - | ❌ No |
| isOnboarded | Boolean | ❌ No | NO | ❌ No |

**Relationships:**
| Name | Destination | Inverse | Type | Delete Rule |
|------|-------------|---------|------|-------------|
| scans | Scan | userProfile | To Many | Cascade |
| regimenEvents | RegimenEvent | userProfile | To Many | Cascade |

---

### Entity 2: Scan

**Attributes:**
| Name | Type | Optional | Default | Indexed |
|------|------|----------|---------|---------|
| id | UUID | ❌ No | - | ✅ Yes |
| timestamp | Date | ❌ No | - | ✅ Yes |
| mode | String | ❌ No | - | ❌ No |
| distanceMM | Double | ❌ No | 0 | ❌ No |
| pose | Transformable | ✅ Yes | - | ❌ No |
| qcFlags | String | ✅ Yes | - | ❌ No |
| imagePath | String | ❌ No | - | ❌ No |
| depthPath | String | ✅ Yes | - | ❌ No |
| intrinsics | Transformable | ✅ Yes | - | ❌ No |
| lightingStats | Transformable | ✅ Yes | - | ❌ No |
| clarityScore | Integer 16 | ❌ No | 0 | ❌ No |

**Relationships:**
| Name | Destination | Inverse | Type | Delete Rule |
|------|-------------|---------|------|-------------|
| userProfile | UserProfile | scans | To One | Nullify |
| lesions | Lesion | scan | To Many | Cascade |
| regionSummaries | RegionSummary | scan | To Many | Cascade |

---

### Entity 3: Lesion

**Attributes:**
| Name | Type | Optional | Default | Indexed |
|------|------|----------|---------|---------|
| id | UUID | ❌ No | - | ✅ Yes |
| stableId | String | ❌ No | - | ✅ Yes |
| scanId | UUID | ❌ No | - | ✅ Yes |
| class | String | ❌ No | - | ❌ No |
| name | String | ✅ Yes | - | ❌ No |
| uvX | Double | ❌ No | 0 | ❌ No |
| uvY | Double | ❌ No | 0 | ❌ No |
| bbox | Transformable | ✅ Yes | - | ❌ No |
| maskPath | String | ✅ Yes | - | ❌ No |
| diameterMM | Double | ❌ No | 0 | ❌ No |
| elevationMM | Double | ❌ No | 0 | ❌ No |
| volumeMM3 | Double | ❌ No | 0 | ❌ No |
| erythemaDeltaAstar | Double | ❌ No | 0 | ❌ No |
| deltaE | Double | ❌ No | 0 | ❌ No |
| confidence | Double | ❌ No | 0 | ❌ No |
| createdAt | Date | ❌ No | - | ❌ No |

**Relationships:**
| Name | Destination | Inverse | Type | Delete Rule |
|------|-------------|---------|------|-------------|
| scan | Scan | lesions | To One | Nullify |

---

### Entity 4: RegionSummary

**Attributes:**
| Name | Type | Optional | Default | Indexed |
|------|------|----------|---------|---------|
| id | UUID | ❌ No | - | ✅ Yes |
| scanId | UUID | ❌ No | - | ✅ Yes |
| region | String | ❌ No | - | ❌ No |
| papuleCount | Integer 16 | ❌ No | 0 | ❌ No |
| pustuleCount | Integer 16 | ❌ No | 0 | ❌ No |
| noduleCount | Integer 16 | ❌ No | 0 | ❌ No |
| comedoneCount | Integer 16 | ❌ No | 0 | ❌ No |
| pihPieCount | Integer 16 | ❌ No | 0 | ❌ No |
| scarCount | Integer 16 | ❌ No | 0 | ❌ No |
| inflamedAreaMM2 | Double | ❌ No | 0 | ❌ No |
| meanDiameterMM | Double | ❌ No | 0 | ❌ No |
| meanElevationMM | Double | ❌ No | 0 | ❌ No |
| meanErythemaDeltaAstar | Double | ❌ No | 0 | ❌ No |
| createdAt | Date | ❌ No | - | ❌ No |

**Relationships:**
| Name | Destination | Inverse | Type | Delete Rule |
|------|-------------|---------|------|-------------|
| scan | Scan | regionSummaries | To One | Nullify |

---

### Entity 5: RegimenEvent

**Attributes:**
| Name | Type | Optional | Default | Indexed |
|------|------|----------|---------|---------|
| id | UUID | ❌ No | - | ✅ Yes |
| userId | UUID | ❌ No | - | ✅ Yes |
| timestamp | Date | ❌ No | - | ✅ Yes |
| products | Transformable | ✅ Yes | - | ❌ No |
| notes | String | ✅ Yes | - | ❌ No |

**Relationships:**
| Name | Destination | Inverse | Type | Delete Rule |
|------|-------------|---------|------|-------------|
| userProfile | UserProfile | regimenEvents | To One | Nullify |

---

## Step 3: Set Transformable Custom Classes

For **Transformable** attributes, set custom class if needed:

1. Select the attribute in Xcode
2. In Data Model Inspector (right panel):
   - **Custom Class**: Leave blank (uses NSObject by default)
   - **Module**: Leave blank
   - **Value Transformer Name**: NSSecureUnarchiveFromData

**Note**: The app code will handle encoding/decoding these types:
- `pose` → `simd_float4x4`
- `bbox` → `CGRect`
- `intrinsics` → `CameraIntrinsics` struct
- `lightingStats` → `LightingStats` struct
- `products` → `[String]`

---

## Step 4: Enable Codegen

For **each entity**, select it and set in Data Model Inspector:

- **Codegen**: Class Definition

This auto-generates the `UserProfile`, `Scan`, `Lesion`, `RegionSummary`, and `RegimenEvent` classes.

---

## Step 5: Set Model Configuration

1. Click on the model file name (`Volcy`) in the left sidebar
2. In Data Model Inspector:
   - **Name**: Volcy
   - **Configurations**: Default

---

## Step 6: Build & Verify

1. Build project (⌘B)
2. Xcode will auto-generate Core Data classes in DerivedData
3. No errors = success! ✅

---

## Troubleshooting

### Error: "Cannot find type 'UserProfile' in scope"
- Make sure Codegen is set to "Class Definition"
- Clean Build Folder (⌘⇧K) and rebuild

### Error: "Multiple entities with name..."
- Check you didn't manually create entity classes
- Delete manual classes, let Codegen handle it

### Error: "Relationship inverse not set"
- Every relationship needs an inverse
- Double-check all relationships match the tables above

---

## Quick Reference: Entity Relationships

```
UserProfile
  ├── scans → [Scan]
  └── regimenEvents → [RegimenEvent]

Scan
  ├── userProfile → UserProfile
  ├── lesions → [Lesion]
  └── regionSummaries → [RegionSummary]

Lesion
  └── scan → Scan

RegionSummary
  └── scan → Scan

RegimenEvent
  └── userProfile → UserProfile
```

---

## Verification Checklist

- [ ] 5 entities created
- [ ] All attributes match tables above
- [ ] All relationships set with inverses
- [ ] Codegen = "Class Definition" for all entities
- [ ] Indexed attributes marked correctly
- [ ] Optional/non-optional matches spec
- [ ] Build succeeds (⌘B)

Once complete, your Core Data model is ready! 🎉
