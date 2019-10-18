#!/usr/bin/env swift

import Foundation

let arguments: [String] = CommandLine.arguments

let rebuildThirdParty = arguments.contains("rebuildThirdParty")
let podInstallationWithRepoUpdate = arguments.contains("podInstallationWithRepoUpdate") || arguments.contains("repoUpdate")
let isVerbose = arguments.contains("verbose")

func shellMaker(isVerbose: Bool) -> (_ arguments: String...) -> Void {
    return { (_ arguments: String...) in
        
        let command = arguments.joined(separator: " ")
        
        print(command)
        
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        if isVerbose, let output: String = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as String? {
            print(output)
        }
    }
}

let shell = shellMaker(isVerbose: isVerbose)

func buildUniversalFramework(path: String, project: String, scheme: String) {
    let pathProject = "\(path)/\(project)"
    
    // Build for device
    shell("xcodebuild",
          "-project \(pathProject)",
        "-scheme \(scheme)",
        "-configuration Release",
        "BUILD_DIR=./build",
        "BUILD_ROOT=./build",
        "-sdk iphoneos")
    
    // Build for simulator
    shell("xcodebuild",
          "-project \(pathProject)",
        "-scheme \(scheme)",
        "-configuration Release",
        "BUILD_DIR=./build",
        "BUILD_ROOT=./build",
        "-sdk iphonesimulator",
        "ARCHS=x86_64",
        "ONLY_ACTIVE_ARCH=NO")
    
    // Ensure the -universal folder is created
    shell("mkdir -p \(path)/build/Release-universal")
    
    // Ensure the project's framework folder is created
    shell("mkdir -p src/NotoriousHuntThirdParty")
    
    // Copy the device framework to the universal folder
    shell("cp -R",
          "\(path)/build/Release-iphoneos/\(scheme).framework",
        "\(path)/build/Release-universal")
    
    // Copy the simulator modules to the universal framework (the device modules are already there)
    shell("cp -R",
          "\(path)/build/Release-iphonesimulator/\(scheme).framework/Modules/\(scheme).swiftmodule/.",
        "\(path)/build/Release-universal/\(scheme).framework/Modules/\(scheme).swiftmodule")
    
    // Call lipo to create the universal framework
    shell("lipo -create -output",
          "\(path)/build/Release-universal/\(scheme).framework/\(scheme)",
        "\(path)/build/Release-iphonesimulator/\(scheme).framework/\(scheme)",
        "\(path)/build/Release-iphoneos/\(scheme).framework/\(scheme)")
    
    // Move the framework to the src folder
    shell("cp -R",
          "\(path)/build/Release-universal/\(scheme).framework",
        "src/NotoriousHuntThirdParty")
    
    shell("rm -rf \(path)/build")
}

shell("bundle install --path .bundle/")

if rebuildThirdParty {
    shell("pod deintegrate")
    shell("rm -rf Pods")
    shell("rm -f Podfile.lock")
}

shell("rm -rf NotoriousHunt.xcodeproj")
shell("rm -rf NotoriousHunt.xcworkspace")
shell("rm -rf ~/Library/Developer/Xcode/DerivedData")

shell("xcodegen generate --spec project.yml")

if rebuildThirdParty {
    print("The pod installation will begin now. This step can take a while (we will prebuild each pod as a compiled framework)")
}

if podInstallationWithRepoUpdate {
    shell("bundle exec pod install --repo-update")
} else {
    shell("bundle exec pod install")
}

if rebuildThirdParty {
    print("The modules installation will begin now. This step can take a while (we will prebuild the module as as a compiled framework)")
}

// run the fixSchemes.rb, due to a issue on the xcodegen related the ondemand and continuous apps exist on the same Xcode project
shell("bundle exec ruby fixScheme.rb")

print("Done! Open the project using the .xcworkspace file")

