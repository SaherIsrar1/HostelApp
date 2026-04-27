# 🏠 HostelHub — Student Hostel Finder App

A **Flutter mobile application** designed for students to discover, compare, and book hostels with ease. Admins can manage listings, review bookings, and track revenue — all in one place.

---

## ✨ Special Feature: Developer Code Hub → Student Hostel Hub

HostelHub includes a unique hostel discovery system that allows students to:

- **🔍 Search & Filter** — Browse hostels by city, gender (Boys/Girls), price, and rating
- **🗺️ Live Map View** — Explore hostel locations on an interactive CartoDB map with real-time GPS
- **📞 One-Tap Contact** — Call or WhatsApp hostel owners directly from the app
- **⭐ Reviews & Ratings** — Read and write verified reviews to help other students decide
- **📋 Smart Booking** — Book with room type, meal plan, duration, and CNIC details
- **🔔 Stay Updated** — Get notified about booking status (Pending → Confirmed)

---

## 🎯 Current Status

### ✅ **Backend (Firebase): 100% Complete**
- Firebase Authentication (Email/Password)
- Cloud Firestore database (7 collections)
- Cloudinary image storage & upload
- Role-based access (Student / Admin)
- Real-time data streams via Firestore snapshots

### ✅ **Frontend UI: 95% Complete**
- 10+ fully designed screens
- Animated splash screen
- Navy & Sage premium color theme
- Instagram-style skeleton loading
- Responsive layouts with smooth animations
- Dark gradient headers with glassmorphism cards

### ⚠️ **In Progress: 5% Remaining**
- **OAuth** (Google Sign-In)
- **Push notifications** (booking status changes)
- **Infinite scroll** on hostel list
- **Image optimization** (lazy load + cropping)
- **Password reset** flow

---

## 🔥 Priority Features

### **Completed This Sprint**
1. ✅ **Color Palette Overhaul** — Navy Blue + Sage Green + Warm Off-White
2. ✅ **Map Upgrade** — Replaced OpenStreetMap with CartoDB Voyager (sharper, modern tiles)
3. ✅ **Skeleton Loaders** — Instagram-style shimmer loading on all list & detail screens
4. ✅ **Booking System** — Full booking form with room type, meal plan, duration slider
5. ✅ **Review System** — Star ratings + comments with user verification

### **Next Up**
1. Push notifications (FCM)
2. Google OAuth login
3. Password reset via email
4. Infinite scroll for hostel list
5. Booking history export (PDF)

---

## 🚀 Quick Start

### **Prerequisites**
- Flutter SDK `^3.9.2`
- Dart SDK (included with Flutter)
- Android Studio / VS Code
- Firebase project configured

### **Clone & Run**

```bash
git clone https://github.com/your-username/hostel-hub.git
cd hostel-hub

# Install dependencies
flutter pub get

# Run on connected device
flutter run
```

### **Environment Setup**

1. Create your Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Authentication** (Email/Password) and **Cloud Firestore**
3. Download `google-services.json` → place in `android/app/`
4. Configure `lib/firebase_options.dart` with your project settings

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure
```

5. Set up **Cloudinary** for image uploads:

```
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_UPLOAD_PRESET=your_upload_preset
```

Update `lib/services/cloudinary_service.dart` with your credentials.

---

## 📱 App Screens

| Screen | Role | Status |
|---|---|---|
| Splash Screen | Both | ✅ Done |
| Login / Register | Both | ✅ Done |
| Hostel List | Student | ✅ Done |
| Hostel Detail | Student | ✅ Done |
| Hostel Map View | Student | ✅ Done |
| Booking Form | Student | ✅ Done |
| My Bookings | Student | ✅ Done |
| Add Review | Student | ✅ Done |
| Admin Dashboard | Admin | ✅ Done |
| Add Hostel | Admin | ✅ Done |
| Edit Hostel | Admin | ✅ Done |
| Location Picker | Admin | ✅ Done |

---

## 🛠️ Tech Stack

### **Mobile (Flutter)**
- **Flutter** `^3.9.2` — Cross-platform UI framework
- **Dart** — Programming language
- **Provider / setState** — State management

### **Backend & Data**
- **Firebase Auth** `^6.1.1` — Authentication
- **Cloud Firestore** `^6.0.3` — NoSQL database + real-time streams
- **Cloudinary** `^0.23.1` — Image storage & CDN

### **Maps & Location**
- **flutter_map** `^8.2.2` — Map rendering engine
- **CartoDB Voyager** — Free, crisp map tiles (no API key needed)
- **latlong2** `^0.9.1` — Coordinate model
- **geolocator** `^10.0.0` — GPS & distance calculation

### **UI & UX**
- **lottie** `^3.0.0` — Animated illustrations
- **image_picker** `^1.0.7` — Gallery & camera access
- **url_launcher** `^6.2.2` — Call, WhatsApp, Google Maps
- **intl** `^0.19.0` — Date formatting

---

## 📊 Feature Overview

### **Student Features**
✅ Register & Login with email  
✅ Browse hostels by city  
✅ Filter by gender (Boys / Girls / All)  
✅ Search by hostel name  
✅ View full hostel detail (images, description, facilities)  
✅ Interactive map with GPS distance  
✅ One-tap WhatsApp / Call contact  
✅ Book hostel (room type, meal plan, duration, CNIC)  
✅ View booking history  
✅ Write & edit reviews with star ratings  
✅ See hostel ratings aggregated from real reviews  

### **Admin Features**
✅ Dedicated Admin Dashboard with statistics  
✅ Add new hostel with images, amenities, contact  
✅ Interactive map-based location picker  
✅ Edit hostel details  
✅ Manage bookings (Confirm / Reject)  
✅ Real-time revenue tracking  
✅ View all pending/confirmed/rejected bookings  

### **Missing / Planned**
❌ Google OAuth login  
❌ Password reset via email  
❌ FCM push notifications  
❌ Infinite scroll on hostel list  
❌ Booking receipt / PDF export  
❌ Chat between student & admin  
❌ Favourite / Wishlist hostels  

---

## 🗂️ Project Structure

```
lib/
├── firebase_options.dart       # Firebase configuration
├── main.dart                   # App entry point
│
├── models/
│   ├── hostel_model.dart       # Hostel data model
│   ├── booking_model.dart      # Booking data model
│   └── comment_model.dart      # Review/comment model
│
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── signup_screen.dart
│   ├── common/
│   │   └── splash_screen.dart
│   ├── student/
│   │   ├── hostel_list_screen.dart
│   │   ├── hostel_detail_screen.dart
│   │   ├── hostel_map_screen.dart  ← CartoDB Voyager maps
│   │   ├── booking_screen.dart
│   │   ├── my_bookings_screen.dart
│   │   └── add_review_screen.dart
│   └── admin/
│       ├── admin_dashboard.dart
│       ├── add_hostel_screen.dart
│       ├── edit_hostel_screen.dart
│       └── location_picker_screen.dart
│
├── services/
│   ├── auth_service.dart
│   ├── hostel_service.dart
│   ├── booking_service.dart
│   └── comment_service.dart
│
├── utils/
│   └── app_colors.dart         # Navy & Sage theme palette
│
└── widgets/
    ├── custom_button.dart
    ├── custom_textfield.dart
    ├── rating_stars.dart
    └── skeleton_loader.dart    ← Instagram-style shimmer loaders
```

---

## 🎨 Design System

### **Color Palette — Navy & Sage**

| Role | Color | Hex |
|---|---|---|
| Primary | Deep Navy Blue | `#1E3A8A` |
| Secondary | Darker Navy | `#0F2C59` |
| Accent | Soft Sage Green | `#8FBC8F` |
| Background | Warm Off-White | `#F8F5F0` |
| Text Dark | Blue-Grey | `#1E293B` |
| Grey | Medium Grey | `#64748B` |

### **UX Highlights**
- 🌀 **Skeleton loading** on all data-heavy screens (Instagram-style shimmer)
- 🗺️ **CartoDB Voyager** — modern, crisp map tiles replacing OpenStreetMap
- 💫 **Animated splash screen** with scale + slide + fade transitions
- 🎴 **Card-based UI** with soft shadows and rounded corners
- 📱 **Gradient AppBars** with Navy → Deep Navy flow

---

## 🗺️ Development Roadmap

### **Sprint 1: Core App** ← ✅ **DONE**
- Firebase integration (Auth + Firestore)
- Student hostel browsing and booking
- Admin CRUD for hostel management
- Map integration with GPS

### **Sprint 2: Polish & UX** ← ✅ **DONE**
- Navy & Sage color theme
- Skeleton loading (Instagram-style)
- CartoDB Voyager maps
- Review & rating system

### **Sprint 3: Notifications & Auth** ← 🔄 **NEXT**
- FCM push notifications
- Google OAuth sign-in
- Password reset via email
- Booking status email alerts

### **Sprint 4: Advanced Features**
- In-app chat (student ↔ admin)
- Hostel wishlist / favourites
- Booking PDF receipts
- Infinite scroll + pagination
- Image lazy loading & optimization

### **Month 2: Launch Prep**
- Performance profiling
- Crash analytics (Firebase Crashlytics)
- App Store / Play Store assets
- Beta testing with real users
- Production Firebase rules hardening

---

## 📈 Metrics

**Overall Completion:** ~70%

| Layer | Progress |
|---|---|
| Firebase Backend | 100% |
| UI Screens | 95% |
| Core Features | 90% |
| Integration | 85% |
| Advanced Features | 15% |

**Time to Public Beta:** 3–4 weeks (part-time)  
**Time to Play Store:** 6–8 weeks  

---

## 🔐 Security Notes

- Firestore security rules restrict hostel writes to `isAdmin == true` users
- Student data (CNIC, phone) stored only in `bookings` collection
- No sensitive data cached locally
- Cloudinary upload preset uses unsigned upload (read-only from client)

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes and test on a real device
4. Submit a PR with a clear description of changes

---

## 📝 Notes

**Strengths:**
- Clean MVVM-ready architecture (easy to migrate to Provider/Riverpod)
- Firebase real-time streams for instant UI updates
- Modular service layer — each feature has its own service class
- Role-based routing (student vs. admin) at splash screen

**Known Limitations:**
- Cloudinary credentials currently hardcoded (move to `.env` before production)
- No pagination yet — loads all hostels per city in one query
- Booking IDs use hostel name as key (should use Firestore document ID)

**Next Action:**  
Implement FCM push notifications for booking status updates.

---

## 📞 Support & Docs

- **`FEATURES_STATUS.md`** — Detailed feature implementation status
- **`TODO.md`** — Sprint-by-sprint development checklist
- Firebase Console — Firestore, Auth, Storage monitoring

---

**Last Updated:** April 27, 2026  
**Version:** 1.0.0+1  
**Status:** Active Development — Sprint 2 Complete ✅
