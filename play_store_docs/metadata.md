# Google Play Store Listing & Metadata

## App Name / Title (Max 30 chars)
`JSON LD Visual Editor`

## Short Description (Max 80 chars)
`Create, edit, and validate compliant Schema.org JSON-LD structured data offline.`

## Full Description (Max 4000 chars)
```text
Optimize your website's search engine optimization (SEO) and reach the top rankings with JSON LD Visual Editor! This offline-first utility is a complete IDE and visual builder designed for developers, digital marketers, and webmasters to build, validate, and export flawless Schema.org structured data in JSON-LD format.

Whether you need to generate schema markup for a Recipe, Person, LocalBusiness, Organization, Product, Event, or any of the 800+ compliant Schema.org classes, JSON LD Visual Editor makes it simple, intuitive, and error-free.

=== Key Features ===

• FULL SCHEMA.ORG COMPLIANCE
Dynamically pulls and caches the latest official Schema.org specifications containing over 1010 classes, 1676 properties, and 81 enumeration types.

• OFFLINE FIRST & PRIVACY-RESPECTING
Your data is Yours. All your documents and visual visual markups are stored 100% locally on your device's secure Drift/SQLite database. No user tracking, no third-party analytic SDKs, and absolutely no ads.

• COMPREHENSIVE VISUAL BUILDER
Easily create and duplicate structured documents. Build complex hierarchies with nested objects, link compliant entities together, and input types like text, dates, numbers, and boolean values through semantic UI inputs.

• INSTANT JSON-LD GENERATION
View your generated JSON-LD code update in real-time in the output window. Copy code to your clipboard with a single tap, or download the valid `.jsonld` file directly.

• GOOGLE RICH RESULTS LINK
Boost your search visibility by instantly opening and validating your schemas on Google's official Rich Results Test tool.

=== Why Choose JSON LD Visual Editor? ===
• Paid-once offline-first visual editor with zero subscription fees.
• Designed with a clean, fully responsive interface featuring both Light and Dark modes.
• Interactive hierarchical tree view and graph structures for visual editing.
• Developed with modern Flutter design language for lightning-fast performance.

Empower your SEO today with the ultimate visual Schema IDE by Antinna!
```

## Categorization & Details
* **Category:** Productivity / Tools
* **Tag Options:** SEO, Developer Tools, Web Development, Utilities
* **Content Rating:** PEGI 3 / Everyone
* **Contains Ads:** No
* **Is Paid:** Yes

## Release Notes (v1.0.0)
`Initial production release of JSON LD Visual Editor. Complete offline schema builder with official Schema.org specs integration.`

---

## 🔒 Google Play Console Compliance & Storage Permissions

To guarantee a fast, seamless review process on the Google Play Console and ensure compliance with Google's strict **Scoped Storage Policies**, the app conforms to the following guidelines:

### 1. Zero Dangerous Broad Permissions
The application does **NOT** declare or use:
* `android.permission.MANAGE_EXTERNAL_STORAGE` (highly regulated and flagged by Google Play Console).
* Broad unrestricted storage permissions on modern Android versions.

### 2. Backward Compatible Permission Model
* `android.permission.WRITE_EXTERNAL_STORAGE` is strictly constrained using `android:maxSdkVersion="28"`:
  ```xml
  <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>
  ```
  This enables seamless writing compatibility to the public `/storage/emulated/0/Download` directory on older legacy Android devices (API level 28 and below), while being entirely bypassed on Android 10+ (API 29+) where permissions are unnecessary.

### 3. Modern Scoped Storage Implementation
For Android 10+ (API 29+):
* **Primary Path:** The app safely attempts to write exported `.jsonld` files directly into the public `/storage/emulated/0/Download` folder. On modern Android versions, creating a new media/download file is natively permitted without requiring any runtime permissions.
* **Secondary Scoped Storage Path:** If a direct public folder write is restricted on certain custom ROMs or configurations, the app automatically falls back to saving files inside the app-specific scoped storage downloads directory (`/storage/emulated/0/Android/data/com.antinna.jsonld/files/Download`). This folder is fully accessible by the user using any standard file explorer and requires no permissions.

### 4. App Content Declarations in Play Console
When filling out the **App Content** dashboard in Google Play Console, set:
* **Privacy Policy URL:** Link to the Hosted Privacy Policy (matching `/play_store_docs/privacy_policy.md`).
* **Sensitive Permissions:** Declare "No" to using broad or sensitive permissions.
* **Financial Features:** Declare "No" to financial features/services.
