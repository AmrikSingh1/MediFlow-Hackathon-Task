# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# OpenGL exceptions
-keep class javax.microedition.khronos.** { *; }
-keep class android.opengl.** { *; }
-dontwarn javax.microedition.khronos.**
-dontwarn android.opengl.**
-dontwarn org.apache.commons.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# For Flutter plugins that use platform views
-keep class androidx.** { *; }
-keep class io.flutter.plugin.platform.** { *; } 