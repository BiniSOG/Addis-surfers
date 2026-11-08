# The Google Mobile Ads SDK starts WorkManager at app launch. WorkManager uses
# Room, which creates its generated *_Impl database classes by reflection.
# Without these rules R8 strips them and the release app crashes on startup:
#   "Failed to create an instance of androidx.work.impl.WorkDatabase"
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.impl.** { *; }
-keep class androidx.room.** { *; }
-dontwarn androidx.room.paging.**

# Google Mobile Ads / Play services.
-keep class com.google.android.gms.ads.** { *; }
-keep class io.flutter.plugins.googlemobileads.** { *; }
