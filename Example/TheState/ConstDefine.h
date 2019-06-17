//
//  ConstDefine.h
//  ThouTool
//
//  Created by thou on 6/3/16.
//  Copyright © 2016 thou. All rights reserved.
//

#ifdef theExporeConst
    #define exportConst(type,name,value) type const name = value
#else
    #ifdef __cplusplus
        #define exportConst(type,name,value) extern "C" __attribute__((visibility ("default"))) type const name
    #else
        #define exportConst(type,name,value) extern __attribute__((visibility ("default"))) type const name
    #endif
#endif

#define exportNSString(name,value) exportConst(NSString *,name,value)
#define exportNSInteger(name,value) exportConst(NSInteger,value)
#define exportNSUInteger(name,value) exportConst(NSUInteger,name,value)
#define exportCGFloat(name,value) exportConst(CGFloat,name,value)


#define exportNSStringUnique(name) exportNSString(name,@#name)
