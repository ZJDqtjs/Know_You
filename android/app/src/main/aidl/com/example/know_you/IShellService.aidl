// IShellService.aidl
package com.example.know_you;

interface IShellService {
    void destroy() = 16777114;
    
    int executeCommand(String command) = 1;
    String executeCommandWithOutput(String command) = 2;
}
