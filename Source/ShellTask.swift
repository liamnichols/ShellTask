//
//  ShellTask.swift
//  ShellTask
//
//  Created by Liam Nichols on 20/02/2016.
//  Copyright © 2016 Liam Nichols. All rights reserved.
//

import Foundation

/// Simple wrapper of NSTask that supports async execution and easy error and output handling.
final class ShellTask {
    
    /// Options for processing output channels
    enum IOOption {
        
        /// Print the output using Swift's `print` function with an optional argument is a prefix to be applied when supplied.
        case Print(prefix: String?)
        
        /// Pass the raw NSData back out as it is recieved (in chunks via NSFileHandle) into the closure.
        case Handle(callback: (availableData: NSData) -> Void)
    }
    
    /// Used to indicate the result of the task being performed.
    enum Result {
        
        /// The task returned with exit code `EXIT_SUCCESS` (0)
        case Success
        /// The task returned with an exit code that wasn't `EXIT_SUCCESS` (0), terminationStatus is passed into the first argument.
        case Failure(Int32)
    }
    
    /// The launchPath of the task being executed. Supplied on init.
    let launchPath: String
    
    /// The arguments being passed into the backing NSTask. Optional
    var arguments: [String]? = nil
    
    /// The environment variables that might need passing into the backing NSTask. Optional
    var environment: [String: String]?  = nil
    
    /// The current directory path used when executing the NSTask. Pass nil to specify the current directory
    var currentDirectoryPath: String? = nil

    /// Options for processing the `standardOutput` NSFileHandle
    var outputOptions = [IOOption]()
    
    /// Options for processing the `standardError` NSFileHandle
    var errorOptions = [IOOption]()
    
    init(launchPath: String) {
        self.launchPath = launchPath
        self.taskQueue.name = "ShellTask.LaunchQueue"
    }
    
    deinit {
        reset()
    }
    
    private let taskQueue = NSOperationQueue()
    private var notificationTokens = [NSObjectProtocol]()
    private var task = NSTask()
    private var errorPipe = NSPipe()
    private var outputPipe = NSPipe()
    private var errorReachedEOF = false
    private var outputReachedEOF = false
    private var errorRecievedData = false
    private var outputRecievedData = false
    private var terminationStatus: Int32? = nil
    private var completion: ((result: ShellTask.Result) -> Void)?
    
    private func reset() {
        
        // remove notification center observers
        for token in notificationTokens {
            NSNotificationCenter.defaultCenter().removeObserver(token)
        }
        notificationTokens.removeAll()
        
        // reset vars ready for next time
        task = NSTask()
        outputPipe = NSPipe()
        errorPipe = NSPipe()
        outputReachedEOF = false
        errorReachedEOF = false
        outputRecievedData = false
        errorRecievedData = false
        terminationStatus = nil
        completion = nil
    }
    
    /// Determines if the reciver is currently processing a call to `launch(completion:)`.
    var isRunning: Bool {
        return completion != nil
    }
    
    /// Launches the task represented by the reciever asynchronously.
    func launch(completion: (result: ShellTask.Result) -> Void) {
        
        // launching while the task is already running is not supported.
        if isRunning {
            fatalError("The instance of ShellTask has already launched.")
        }
        
        // log
        print("[ShellTask] Launching:", launchPath, arguments?.joinWithSeparator(" ") ?? "")
        
        // store our completion handler, this signifies that the task has now began.
        self.completion = completion
        
        // set up the backing NSTask
        task.launchPath = launchPath
        task.arguments = arguments
        if let environment = environment {
            task.environment = environment
        }
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        if let currentDirectoryPath = self.currentDirectoryPath {
            task.currentDirectoryPath = currentDirectoryPath
        }
        
        // run the next parts on the task queue
        taskQueue.addOperation(NSBlockOperation {
        
            // configure file handles
            self.setupPipe(self.outputPipe)
            self.setupPipe(self.errorPipe)
            
            // setup a handler for when the task completes
            self.setupTerminationForTask(self.task)
            
            // launch the task
            self.task.launch()

            // wait for the task and file handles to complete
            while !self.hasCompleted() {
                NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate.distantFuture())
            }
            
            // complete the task
            dispatch_async(dispatch_get_main_queue()) {
                self.complete()
            }
        })
    }
    
    private func complete() {
        
        // just double check for completion and terminationStaus
        if let completion = self.completion, let terminationStatus = self.terminationStatus {
            
            // call the completion handler
            if terminationStatus == EXIT_SUCCESS {
                completion(result: .Success)
            } else {
                completion(result: .Failure(terminationStatus))
            }
            
            // reset as we've finished.
            self.reset()
            
        } else {
            // this should never happen.
            fatalError("completion or termination status aren't present but the task completed.")
        }
    }
    
    private func hasCompleted() -> Bool {
        return outputReachedEOF && errorReachedEOF && terminationStatus != nil
    }
}

// MARK: - File Handles
private extension ShellTask {
    
    func setupPipe(pipe: NSPipe) {
        
        // get the vars we need
        let center = NSNotificationCenter.defaultCenter()
        let name = NSFileHandleDataAvailableNotification
        let handle = pipe.fileHandleForReading
        let callback = fileHandleDataAvailableBlock
        
        // wait for data
        handle.waitForDataInBackgroundAndNotify()
        
        // add the observer
        let token = center.addObserverForName(name, object: handle, queue: taskQueue, usingBlock: callback)
        notificationTokens.append(token)
    }
    
    func fileHandleDataAvailableBlock(notification: NSNotification) {
        if let fileHandle = notification.object as? NSFileHandle {
            fileHandleDataAvailable(fileHandle)
        }
    }
    
    func fileHandleDataAvailable(fileHandle: NSFileHandle) {
        
        let availableData = fileHandle.availableData
        
        // process the IOOptions if there are any
        if fileHandle === outputPipe.fileHandleForReading {
            processData(availableData, withOptions: outputOptions, initialChunk: !outputRecievedData)
        } else if fileHandle === errorPipe.fileHandleForReading {
            processData(availableData, withOptions: errorOptions, initialChunk: !errorRecievedData)
        }
        
        // check for EOF
        if availableData.length == 0 {
            fileHandleReachedEOF(fileHandle)
        }
        
        // flag that we've recieved data
        if fileHandle === outputPipe.fileHandleForReading && !outputRecievedData {
            outputRecievedData = true
        } else if fileHandle === errorPipe.fileHandleForReading && !errorRecievedData {
            errorRecievedData = true
        }
        
        // wait for more data
        fileHandle.waitForDataInBackgroundAndNotify()
    }
    
    func fileHandleReachedEOF(fileHandle: NSFileHandle) {
        
        // work out what file handle this was and record that it's hit EOF
        if fileHandle === outputPipe.fileHandleForReading {
            outputReachedEOF = true
        } else if fileHandle === errorPipe.fileHandleForReading {
            errorReachedEOF = true
        }
    }
}

// MARK: - IOOption
private extension ShellTask {
    
    func processData(availableData: NSData, withOptions options: [IOOption], initialChunk: Bool) {
        
        // loop through the options and switch on each one
        for option in options {
            
            switch option {
                
            case let .Print(prefix):
                // print the NSData via `print`
                if let chunk = String(data: availableData, encoding: NSUTF8StringEncoding) {
                    printChunk(chunk, prefix: prefix, initialChunk: initialChunk, EOF: availableData.length == 0)
                }
                
            case let .Handle(callback):
                // pass the data back through the closure
                callback(availableData: availableData)
            }
        }
    }
    
    func printChunk(chunk: String, prefix: String?, initialChunk: Bool, EOF: Bool) {
        
        // work out if we need to process the prefix (EOF is just a new line)
        if let prefix = prefix where EOF == false {
            
            // we will eventually print this.
            var output = chunk
            
            // we need to append the prefix to `chunk` if `initialChunk == true`
            if initialChunk == true {
                output = prefix + " " + output
            }
            
            // replace `\n` characters with the `"\n" + prefix + " "`
            output = output.stringByReplacingOccurrencesOfString("\n", withString: "\n" + prefix + " ")
            
            // print it
            print(output, separator: "", terminator: "")
            
        } else {
            // just print the chunk as it is as we don't want to append the prefix anywhere
            print(chunk, separator: "", terminator: EOF ? "\n" : "")
        }
    }
}

// MARK: - Termination
private extension ShellTask {
    
    func setupTerminationForTask(task: NSTask) {
        
        // get the vars we need
        let center = NSNotificationCenter.defaultCenter()
        let name = NSTaskDidTerminateNotification
        let callback = taskDidTerminateBlock
        
        // add the observer
        let token = center.addObserverForName(name, object: task, queue: taskQueue, usingBlock: callback)
        notificationTokens.append(token)
    }
    
    func taskDidTerminateBlock(notification: NSNotification) {
        if let task = notification.object as? NSTask {
            taskDidTerminate(task)
        }
    }
    
    func taskDidTerminate(task: NSTask) {
        terminationStatus = task.terminationStatus
    }
}
