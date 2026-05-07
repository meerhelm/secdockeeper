# Flutter embedding
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.util.** { *; }
-dontwarn io.flutter.embedding.**

# Play Core — Flutter's deferred-components Gradle glue references it.
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# ML Kit text recognition (google_mlkit_text_recognition + Latin-only model)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.mlkit.**

# SQLCipher / sqflite_sqlcipher
-keep class net.zetetic.database.** { *; }
-dontwarn net.zetetic.database.**

# Kotlin metadata used by reflection in some plugins
-keep class kotlin.Metadata { *; }
