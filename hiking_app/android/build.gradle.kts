// android/build.gradle.kts  — project-level

import com.android.build.gradle.BaseExtension
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

// Apply to ALL subprojects that are Android modules
subprojects {
    // Force Kotlin 17 for all Kotlin compile tasks (works for Android & non-Android)
    tasks.withType<KotlinCompile>().configureEach {
        // New compilerOptions DSL (no deprecation warning on Kotlin 2.x)
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
        // Fallback for older Kotlin versions (safe to keep both)
        kotlinOptions.jvmTarget = "17"
    }

    // Force Java 17 for all Android modules (app or library)
    plugins.withId("com.android.application") {
        extensions.configure<BaseExtension> {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }
    plugins.withId("com.android.library") {
        extensions.configure<BaseExtension> {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }
}

// Put this at the bottom of android/build.gradle.kts
project(":mapbox_maps_flutter") {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        // Legacy DSL (always available)
        kotlinOptions.jvmTarget = "1.8"

        // Kotlin 2.x compilerOptions DSL (try if available; safe to ignore if not)
        try {
            @Suppress("UNCHECKED_CAST")
            val getCompilerOptions = this::class.java.getMethod("getCompilerOptions")
            val compilerOptions = getCompilerOptions.invoke(this)
            val getJvmTarget = compilerOptions::class.java.getMethod("getJvmTarget")
            val jvmTargetProp = getJvmTarget.invoke(compilerOptions)
            val setMethod = jvmTargetProp::class.java.getMethod(
                "set", Class.forName("org.jetbrains.kotlin.gradle.dsl.JvmTarget")
            )
            val enumClass = Class.forName("org.jetbrains.kotlin.gradle.dsl.JvmTarget")
            val jvm18 = enumClass.getField("JVM_1_8").get(null)
            setMethod.invoke(jvmTargetProp, jvm18)
        } catch (_: Throwable) { /* ignore if not present */ }
    }
}

// IMPORTANT: Do NOT use options.release or javaToolchains here for Android modules.
// AGP needs to wire the Android bootclasspath itself.