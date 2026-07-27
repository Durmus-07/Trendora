# WorkManager creates Room's generated database implementation through reflection.
# Keep only the constructor required during AndroidX Startup initialization.
-keepclassmembers class androidx.work.impl.WorkDatabase_Impl {
    <init>();
}
