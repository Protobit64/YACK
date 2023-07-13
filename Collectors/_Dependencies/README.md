This is the folder that all dependencies for the collectors should go.

Example
If you have a collectors that requires autorunsc.exe to run
then you should move the binary into the _Dependency folder. 
The collector must also include the directive:
    .DEPENDENCY autorunsc.exe
at the top of the script.