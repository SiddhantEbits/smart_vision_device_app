# Keep SnakeYAML classes
-keep class org.yaml.snakeyaml.** { *; }
-keep class java.beans.** { *; }

# Keep all model classes that might be serialized
-keep class com.app.smart_vision.** { *; }
-keep class com.deviceapp.smart_vision.** { *; }
