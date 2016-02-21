//
//  Print.swift
//  ShellTaskExample
//
//  Created by Liam Nichols on 21/02/2016.
//  Copyright © 2016 Liam Nichols. All rights reserved.
//

import Foundation

func executeTaskAndPrintOutput(task: ShellTask, prefix: String?) {
    
    // add the print option to our output task
    task.outputOptions = [
        ShellTask.IOOption.Print(prefix: prefix)
    ]
    
    // lets use the same options for errors as well
    task.errorOptions = task.outputOptions
    
    // launch the task
    task.launch { result in
        
        // switch on our result,
        switch result {
        case .Success:
            print("task completed executed successfully.")
            
        case let .Failure(code):
            print("task terminated with code:", code)
        }
        
        // kill the app
        exit(EXIT_SUCCESS)
    }
}