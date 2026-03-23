import com.android.build.gradle.BaseExtension
import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Keep Java and Kotlin bytecode targets aligned across all modules.
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }

    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }

    // Plugin module can still keep Java at 1.8 unless compileOptions are overridden.
    if (name == "receive_sharing_intent") {
        afterEvaluate {
            extensions.findByName("android")?.let { androidExt ->
                (androidExt as BaseExtension).compileOptions.apply {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
    }

    // AGP 8 requires every Android module to declare a namespace.
    // Some third-party plugins (older versions) still omit this, so set a safe fallback.
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library") || plugins.hasPlugin("com.android.application")) {
            val androidExt = extensions.findByName("android") ?: return@afterEvaluate
            try {
                val getNamespace = androidExt.javaClass.getMethod("getNamespace")
                val currentNamespace = getNamespace.invoke(androidExt) as String?

                if (currentNamespace.isNullOrBlank()) {
                    val setNamespace = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                    val fallbackNamespace = "com.example.${project.name.replace('-', '_')}"
                    setNamespace.invoke(androidExt, fallbackNamespace)
                }
            } catch (_: Exception) {
                // Ignore if this AGP type does not expose namespace accessors.
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
