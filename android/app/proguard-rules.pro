# kotlinx.serialization keeps its generated serializers off the entry-point graph,
# so R8 cannot see they are used.
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**

-keepclassmembers class kotlinx.serialization.json.** {
  *** Companion;
}
-keepclasseswithmembers class kotlinx.serialization.json.** {
  kotlinx.serialization.KSerializer serializer(...);
}

-keep,includedescriptorclasses class io.appbeyond.freelance.deep.**$$serializer { *; }
-keepclassmembers class io.appbeyond.freelance.deep.** {
  *** Companion;
}
-keepclasseswithmembers class io.appbeyond.freelance.deep.** {
  kotlinx.serialization.KSerializer serializer(...);
}

# Ktor resolves its engine and plugins reflectively via ServiceLoader.
-keep class io.ktor.** { *; }
-dontwarn io.ktor.**
-dontwarn org.slf4j.**
