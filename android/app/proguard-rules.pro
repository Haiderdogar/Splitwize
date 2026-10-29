# Splitwize release keep rules.
# Flutter enables R8 minify/shrink for release by default. Without these
# keeps, Google Mobile Ads / Firebase / Play Services classes get stripped
# and the process dies in a ContentProvider before Dart can show any UI
# (the "opens then instantly closes" crash on release APKs).

# --- Flutter / embedding ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# --- Firebase ---
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.internal.** { *; }
-dontwarn com.google.firebase.**

# --- Google Mobile Ads (AdMob) ---
# MobileAdsInitProvider runs at process start; stripping these classes
# kills the app before main() runs.
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.gms.internal.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# --- Play Services measurement (pulled in by Firebase) ---
-keep class com.google.android.gms.measurement.** { *; }
-keep class com.google.android.gms.measurement.internal.** { *; }

# --- Google Sign-In ---
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# --- RevenueCat ---
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

# --- Secure storage / SQLite ---
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.tekartik.sqflite.** { *; }

# Keep native methods and @Keep-annotated members.
-keepclassmembers class * {
    native <methods>;
}
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}
