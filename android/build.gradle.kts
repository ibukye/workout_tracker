// ルート build.gradle.kts

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ビルドディレクトリ設定
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")
}

// clean タスク
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
