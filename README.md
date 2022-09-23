# qfiscgen-MATLAB
Is a simple command that takes a FIS object created from the Fuzzy Logic Toolbox and generates C code based on the qFIS engine. The generated code is portable and can be used in any embedded system that supports floating-point operations.

[![View qfiscgen ( Fuzzy C-code generator for embedded systems) on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://la.mathworks.com/matlabcentral/fileexchange/117465-qfiscgen-fuzzy-c-code-generator-for-embedded-systems)

Example : Generate C code from the built-in tipper example:

``` 
qfiscgen( readfis( 'tipper.fis') )
```

Note: Obtain the qFIS engine from https://github.com/kmilo17pet/qlibs (Only qFIS.c and qFIS.h are required)

## Un-supported features
- Custom membership functions
