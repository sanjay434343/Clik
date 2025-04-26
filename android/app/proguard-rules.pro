# ...existing rules...

# Add keep rules for mediapipe classes
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# Keep protobuf classes to avoid missing class errors
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# Avoid warnings for javax.lang.model and related classes
-dontwarn javax.lang.model.**
-dontwarn javax.annotation.**

# Avoid warnings for bouncycastle, conscrypt, and OpenJSSE packages
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**

# ...existing rules...
