allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Tương thích plugin native, đăng ký trước khi các subproject được evaluate.
apply(from = "plugin-compatibility.gradle")

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    layout.buildDirectory.value(newBuildDir.dir(project.name))
    evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
