# Firebase Integration Guide for Windsurf (FINAL)

> **Authoritative Document**
> This file is the **single source of truth** for integrating Firebase (Firestore + FCM) with the **Camera Monitoring System – Firestore Architecture v1.2-A**.
>
> Windsurf **MUST follow this document strictly** when generating or modifying code.

---

## 1. System Context

* **System**: Camera Monitoring & Alerting Platform
* **Clients**: Flutter (Mobile / Tablet / TV), Installer App, Edge Devices
* **Backend**: Firebase (Firestore, FCM, Cloud Functions optional)
* **Region**: `asia-south1` (Mumbai)
* **Design Goal**: High-scale, low-cost, real-time monitoring for India

---

## 2. Core Firestore Design Principles (MANDATORY)

Windsurf **must not violate** the following principles:

* Denormalized reads (duplicate names when needed)
* Flat collections for high-volume writes
* Subcollections ONLY where volume is low
* Composite document IDs to avoid hotspots
* Timestamp fields only (ISO / Firestore Timestamp)
* Array-based scheduling (NO cron, NO bitmasks)
* Encrypted RTSP URLs only
* TTL policies for logs

❌ Never introduce:

* Nested alert/error logs
* Bitmask or cron schedules
* Plain RTSP URLs
* Per-device alert subcollections

---

## 3. Final Firestore Collection Hierarchy

```
devices
 └─ {deviceId}
     └─ cameras
         └─ {cameraId}
             └─ installerTests
                 └─ {algorithmType}

alertLogs
 └─ {device_camera_algorithm_timestamp}

errorLogs
 └─ {device_camera_timestamp}
```

---

## 4. Device Heartbeat & Online / Offline Logic

### Heartbeat Rule

* Each device **MUST update `lastSeen` at least once every hour**
* Update is done by the device or trusted backend

### Status Determination

```text
now = current UTC time

diffMinutes = now - lastSeen

IF diffMinutes <= 60:
  status = "online"
ELSE:
  status = "offline"
```

### Rules

* ❌ Do NOT store `offlineAt`
* ❌ Do NOT use cron jobs
* ✅ Status may be computed dynamically or cached

---

## 5. devices Collection

### Path

```
devices/{deviceId}
```

### Schema (FINAL)

```json
{
  "pairedUserId": "string",
  "hardwareName": "string",
  "status": "online | offline | error",
  "lastSeen": "Timestamp",
  "appVersion": "string",

  "maintenanceMode": "boolean",
  "hardRestart": "boolean",

  "createdAt": "Timestamp",

  "isPaired": "boolean",
  "pairedAt": "Timestamp",
  "pairedBy": "string",

  "alertEnable": "boolean",
  "notificationEnabled": "boolean",

  "fcmToken": "string",
  "fcmTokenUpdatedAt": "Timestamp",

  "whatsapp": {
    "alertEnable": "boolean",
    "phoneNumbers": ["string"]
  }
}
```

---

## 6. cameras Subcollection

### Path

```
devices/{deviceId}/cameras/{cameraId}
```

### Rules

* Algorithms are embedded maps
* No algorithm subcollections
* RTSP URL must be encrypted

### Camera Schema

```json
{
  "cameraName": "string",
  "rtspUrlEncrypted": "ENC:AES256-GCM:base64",
  "createdAt": "Timestamp",

  "algorithms": {
    "ALGORITHM_KEY": {
      "enabled": "boolean",
      "threshold": "number",
      "maxCapacity": "number",

      "absentInterval": "number",
      "alertInterval": "number",
      "cooldownSeconds": "number",

      "appNotification": "boolean",
      "wpNotification": "boolean",

      "schedule": {
        "enabled": "boolean",
        "activeDays": ["MON","TUE","WED","THU","FRI","SAT","SUN"],
        "startMinute": "number",
        "endMinute": "number"
      }
    }
  }
}
```

---

## 7. Algorithm Runtime Evaluation Logic

```text
IF algorithm.enabled == false → SKIP
IF schedule.enabled == false → RUN ALWAYS

IF today NOT IN activeDays → SKIP

now = hour * 60 + minute

IF startMinute <= endMinute:
  RUN if startMinute ≤ now ≤ endMinute
ELSE:
  RUN if now ≥ startMinute OR now ≤ endMinute
```

✔ Supports overnight schedules
✔ Zero Firestore reads at runtime

---

## 8. installerTests Subcollection (FINAL)

### Purpose

Installer validation per camera per algorithm.

### Path

```
devices/{deviceId}/cameras/{cameraId}/installerTests/{algorithmType}
```

### Rules

* One document per algorithm
* Overwrite on each test
* NOT used at runtime

### Schema

```json
{
  "algorithmType": "string",
  "result": "PASS | FAIL",
  "testedAt": "Timestamp",
  "testedBy": "string",
  "notes": "string?",
  "createdAt": "Timestamp"
}
```

---

## 9. alertLogs Collection (HIGH VOLUME)

### Path

```
alertLogs/{device_camera_algorithm_timestamp}
```

### TTL

* 60 days

### Schema

```json
{
  "deviceId": "string",
  "deviceName": "string",
  "cameraId": "string",
  "camName": "string",
  "algorithmType": "string",

  "alertTime": "Timestamp",
  "createdAt": "Timestamp",

  "message": "string",
  "currentCount": "number?",
  "imgUrl": "string?",

  "isRead": "boolean",
  "sentTo": ["string"]
}
```

---

## 10. errorLogs Collection

### Path

```
errorLogs/{device_camera_timestamp}
```

### TTL

* 30 days

### Schema

```json
{
  "deviceId": "string",
  "cameraId": "string",

  "errorType": "string",
  "severity": "INFO | WARN | ERROR",

  "message": "string",

  "timestamp": "Timestamp",
  "createdAt": "Timestamp"
}
```

---

## 11. RTSP URL Encryption (MANDATORY)

* AES-256-GCM only
* Keys via Cloud KMS / Secrets Manager
* Plain RTSP URLs are **forbidden**

---

## 12. Flutter & Windsurf Notes

### Time Conversion

```dart
int startMinute = start.hour * 60 + start.minute;
int endMinute   = end.hour * 60 + end.minute;
```

### Enable Offline Cache

```dart
FirebaseFirestore.instance.settings =
  const Settings(persistenceEnabled: true);
```

---

## 13. Final Collection Summary

### Top-Level Collections

| Collection | Path Example            | TTL     |
| ---------- | ----------------------- | ------- |
| devices    | devices/{deviceId}      | NO      |
| alertLogs  | alertLogs/{compositeId} | 60 days |
| errorLogs  | errorLogs/{compositeId} | 30 days |

### Subcollections

| Parent  | Subcollection  | Path Example                                                         | TTL |
| ------- | -------------- | -------------------------------------------------------------------- | --- |
| devices | cameras        | devices/{deviceId}/cameras/{cameraId}                                | NO  |
| cameras | installerTests | devices/{deviceId}/cameras/{cameraId}/installerTests/{algorithmType} | NO  |

---

## 14. Final Instruction to Windsurf

> This document is **authoritative**.
> If generated code conflicts with this file,
> **THIS FILE OVERRIDES ALL OUTPUT**.

---

✅ END OF DOCUMENT
