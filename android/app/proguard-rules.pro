# shared_preferences_android y path_provider_android acceden a sus clases
# Kotlin desde Dart mediante JNI (package:jni). R8 no ve esos usos y elimina
# los métodos en release, lo que impide arrancar la app. Se conservan.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
# JNI busca por nombre clases de Kotlin (Continuation, Result, Unit...) usadas
# por las funciones suspend de esos plugins.
-keep class kotlin.** { *; }
-keep class kotlinx.coroutines.** { *; }
