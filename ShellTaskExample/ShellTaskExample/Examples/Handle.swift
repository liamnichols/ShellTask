//
//  Handle.swift
//  ShellTaskExample
//
//  Created by Liam Nichols on 21/02/2016.
//  Copyright © 2016 Liam Nichols. All rights reserved.
//

import Foundation

func executeTaskAndHandleOutput(task: ShellTask) {
    
    // somewhere to store the output as we recieve it.
    let buffer = NSMutableData()
    
    // add the handle option to our output. append the data we recieve to our buffer.
    task.outputOptions = [
        ShellTask.IOOption.Handle { availableData in
            buffer.appendData(availableData)
        }
    ]
    
    // launch the task
    task.launch { result in
        
        // at the time of this callback being executed, the output has finished so `buffer` is now complete with all the output data.
        
        // switch on our result,
        switch result {
        case .Success:
            print("task completed executed successfully. the output was \(buffer.length) bytes")
            
        case let .Failure(code):
            print("task terminated with code:", code)
        }
        
        // kill the app
        exit(EXIT_SUCCESS)
    }
}