-keep class org.bouncycastle.** { *; }
-keep class org.conscrypt.** { *; }
-keep class org.openjsse.** { *; }
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class io.flutter.** { *; }

-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

-keep class com.lore.app.MainActivity { *; }
-keep class com.lore.app.** { *; }

-keep class com.lore.app.MainActivity { *; }
-keep class com.lore.app.** { *; }

# Keep ML Kit barcode scanning classes
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }