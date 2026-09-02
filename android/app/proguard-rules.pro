# R8: Missing class org.osgi.annotation.bundle.Export
# This rule tells R8 not to warn or error if it can't find classes
# from the org.osgi.** packages, which are often optional dependencies.
-dontwarn org.osgi.**

# Apache Tika uses Java SE classes not available on Android
-dontwarn javax.xml.stream.**
-dontwarn org.apache.tika.**

# ===== Firebase Crashlytics Rules =====
# NOTE: Firebase Crashlytics Gradle plugin includes most rules automatically.
# We only need to keep line numbers for better crash reports.

# Keep line numbers and source file names for crash reports
-keepattributes SourceFile,LineNumberTable

# ===== Safety Shield Plugin =====
# TensorFlow Lite (ML inference, uses JNI/reflection)
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# ONNX Runtime (ML inference, uses JNI/reflection)
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# Safety Shield plugin classes (Flutter MethodChannel reflection)
-keep class com.snabbit.safetyshield.** { *; }

# ===== Jetpack Compose Rules =====
-keep class androidx.compose.** { *; }
-dontwarn androidx.compose.**

# ===== HiveMQ MQTT client (transitive, via observability SDK) =====
# Official rules from https://hivemq.github.io/hivemq-mqtt-client/docs/installation/android/
# (netty/jctools rely on member names via reflection — required to avoid runtime crashes)
-keepclassmembernames class io.netty.** { *; }
-keepclassmembers class org.jctools.** { *; }

# References optional netty transports/codecs (epoll, websocket, proxy, tcnative),
# log4j loggers, and jetty ALPN that are never present on Android. R8-generated rules.
-dontwarn io.netty.channel.epoll.**
-dontwarn io.netty.handler.codec.http.**
-dontwarn io.netty.handler.proxy.**
-dontwarn io.netty.internal.tcnative.**
-dontwarn org.apache.log4j.**
-dontwarn org.apache.logging.log4j.**
-dontwarn org.eclipse.jetty.alpn.**
-dontwarn org.eclipse.jetty.npn.**
-dontwarn reactor.blockhound.integration.BlockHoundIntegration
