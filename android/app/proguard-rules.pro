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
