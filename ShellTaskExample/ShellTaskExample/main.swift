//
//  main.swift
//  ShellTaskExample
//
//  Created by Liam Nichols on 21/02/2016.
//  Copyright © 2016 Liam Nichols. All rights reserved.
//

import Foundation

// we're using the xcodebuild command to test this project. Make sure this points to the location of this project directory.
let projectDirectory = "/Users/liamnichols/Documents/Developer/Projects/ShellTask/ShellTaskExample"

// Create the task that we want to launch. The below is the equivelent to running
//  `xcodebuild -scheme ShellTaskExample -configuration Release -showBuildSettings` from this projects directory.
let task = ShellTask(launchPath: "/usr/bin/xcodebuild")
task.currentDirectoryPath = projectDirectory
task.arguments = [
    "-scheme", "ShellTaskExample",
    "-configuration", "Release",
    "-showBuildSettings"
]




// play around with the examples below.. only call one or the other.

// just executes the task, doesn't do anything with the output. It'll just report the exit code in its callback
executeBasicTask(task)

// executes the task again, but prints both the error and output channels into the console (via `print()`) with the optional prefix on each line.
//executeBasicTaskAndPrintOutput(task, prefix: "[\(task.launchPath)]")

// executes the task again without recording to the console. The output is however stored into a buffer and then read back in the completion block when it is complete.
//executeTaskAndHandleOutput(task)




// keep the util running
dispatch_main()
