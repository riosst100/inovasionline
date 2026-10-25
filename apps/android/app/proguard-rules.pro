# Picked up automatically by the Flutter Gradle plugin for release builds.
#
# R8 full mode (AGP 8+) no longer keeps the no-arg constructor of a class kept by a bare
# `-keep class X`. Older libraries rely on that and instantiate these classes reflectively:

# WorkManager (via Firebase) builds WorkDatabase_Impl with Room's reflection; room-runtime 2.2.5's
# own rule keeps only the class, so release builds crashed at startup with
# "Failed to create an instance of androidx.work.impl.WorkDatabase".
-keep class * extends androidx.room.RoomDatabase { <init>(); }

# Firebase / ML Kit discover their ComponentRegistrars by class name and call the no-arg
# constructor; without it ML Kit (face detection) components silently fail to register.
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }
