# ShellTask
Simple wrapper of `NSTask` that supports async execution and easy error and output handling.

### Introduction
So I was writing a command line app in Swift and needed to execute a bunch of command line tasks from within. Turns out that getting the complete output from large commands was a little bit tricky and a lot of the stuff I found on the internet was either really outdated or just useless to me. Hence `ShellTask`. A simple class that wraps `NSTask` allowing you to easily create, launch and process the output of a command asynchronously.

### Installation

Well at the moment, you just need to drag `ShellTask.swift` into your project and it should just work.  
I haven't added Swift Package Manager, Cocoapod or Carthage support yet because I don't know how well this works in all scenarios so please let me know and we can look at other installation alternatives later.  
**Also only tested it on OS X using Xcode 7.2.1, I don't know if `NSTask` works on Linux using open source stuff.**

### Examples

Check out the ShellTaskExample project in the repo, its got most stuff covered.

##### Creating a basic task:  
    let task = ShellTask(launchPath: "/usr/bin/curl")
    task.arguments = [ "https://api.github.com/" ]

This task is the equivalent to calling `curl https://api.github.com/` from terminal.

##### Launching a task:
    // launch the task
    task.launch { result in
        
        // switch on our result,
        switch result {
        case .Success:
            print("task completed executed successfully.")
            
        case let .Failure(code):
            print("task terminated with code:", code)
        }
    }
    
This will launch the task asynchronously and report back a `ShellTask.Result` enum value indicating the success of the task.   
* `.Success` means that the `NSTask` returned a `terminationStatus` of `EXIT_SUCCESS` (0).  
* `.Failure(Int32)` means that the `terminationStatus` was not `EXIT_SUCCESS` and the actual status is the supplied argument.

##### I/O Channel Options
By default, there are no `ShellTask.IOOption` values set on either `outputOptions` or `errorOptions`. This means that the ouput is not processed in any way. There are however some options available:

* `.Print(prexix: String?)` By setting this option, the task will print the output received on the file handle directly via the `print()` function in Swift. There is also an optional `prefix` parameter that will be added to each line of the output if supplied.
* `Handle(callback: (availableData: NSData) -> Void)` By setting this option, the task will callback to the supplied closure (`callback`) whenever there is data available. This is called directly from the`NSFileHandleDataAvailableNotification` notification allowing you to manually process the data yourself if you want.

You can use these options in conjunction with each other if you would like.

**Printing with a Prefix:**  

    task.outputOptions = [
        ShellTask.IOOption.Print(prefix: "[xcodebuild]")
    ]

**Handling the output manually:**  

    // somewhere to store the output as we recieve it.
    let buffer = NSMutableData()
    
    // add the handle option to our output. append the data we receive to our buffer.
    task.outputOptions = [
        ShellTask.IOOption.Handle { availableData in
            buffer.appendData(availableData)
        }
    ]
    
    // launch the task
    task.launch { result in
        
        // at the time of this callback being executed, the output has finished so `buffer` is now complete with all the output data.
        print(buffer)
    }

    
### License

Do what you want with it.

### Conclusion

Let me know if it doesn't work and I'll see if I can help.
Enjoy
