//
//  NSObject+BKInject.m
//
//  Created by Brian King on 12/12/13.
//  Copyright (c) 2013 Brian King. All rights reserved.
//

#import "NSObject+BKInject.h"

#if TARGET_OS_IPHONE
  #import <objc/runtime.h>
  #import <objc/message.h>
#else
  #import <objc/objc-class.h>
#endif

typedef void* (^BKInjectReturnBlock)(id self, ...);
typedef void  (^BKInjectNoReturnBlock)(id self, ...);

#define MIN_ARG_SIZE 4

#define assignArgumentIf(type, vaType, argType, args, i) \
else if (!strcmp(argType, @encode(type))) {\
vaType arg = va_arg(args, vaType);\
[invocation setArgument:&arg atIndex:i];\
}

@implementation NSObject (BKInject)

+ (BOOL)bk_injectMethod:(SEL)selector before:(BKInjectBlock)before after:(BKInjectBlock)after
{
    // Fail if the selector does not exist.
    Method origMethod = class_getInstanceMethod(self, selector);
    if (!origMethod)
    {
        return NO;
    }

    // Add an over-ride of the method to this class.   If the method belongs to a sub-class
    // swizzling the method would impact all sub-classes of the object that this selector was
    // defined in.
    //
    // If this selector is defined in this class (not a super class), this will return NO, and that's fine.
    class_addMethod(self,
                    selector,
                    class_getMethodImplementation(self, selector),
                    method_getTypeEncoding(origMethod));
    
    // Create the method to swizzle to.  This will just prepend the selector with a unique key.
    SEL injectSelector = NSSelectorFromString([@"bk_injectMethod_before_after__" stringByAppendingString:NSStringFromSelector(selector)]);
    
    // Get the method signature of the class.   The block that is defined must have a matching signature for the selector.   The
    // argument list is not an issue, since the block has a variable argument list, but the return type must match.  We only differentiate
    // void and non-void.
    NSMethodSignature *signature = [self.class instanceMethodSignatureForSelector:selector];
    
    id internalBlock = nil;
    BOOL isVoidBlock = strcmp([signature methodReturnType], @encode(void)) == 0;
    if (isVoidBlock)
    {
        // These block definitions should be cleaned up.   Waiting to know that there's not a substantially better way of doing this
        // before cleanup.  Largely, I'm failing at handling va_list cleanly.
        BKInjectNoReturnBlock voidBlock = ^(NSObject *target, ...)
        {
            va_list args;
            va_start(args, target);
            NSInvocation *invocation = [self bk_invocationWithSignature:signature target:target selector:injectSelector andArgs:args];
            
            if (before) { before(invocation); }
            
            [invocation invoke];
            
            if (after)  { after(invocation);  }
            va_end(args);
        };
        internalBlock = voidBlock;
    }
    else
    {
        // I believe there will be undefined behavior if the return length is greater than sizeof(void*).
        NSAssert([signature methodReturnLength] == sizeof(void*), @"Method return length is bigger than sizeof(void *).");

        BKInjectReturnBlock returnBlock = ^void*(NSObject *target, ...)
        {
            va_list args;
            va_start(args, target);
            NSInvocation *invocation = [self bk_invocationWithSignature:signature target:target selector:injectSelector andArgs:args];
            va_end(args);

            if (before) { before(invocation); }
            
            [invocation invoke];
            
            if (after)  { after(invocation);  }

            void *returnValue = nil;
            [invocation getReturnValue:&returnValue];
            return returnValue;
        };
        internalBlock = returnBlock;
    }
    Method injectMethod = class_getInstanceMethod(self, injectSelector);
    if (injectMethod)
    {
        // If the method has been injected before, the injectMethod will already exist.
        // Replace the implementation with the new implementation.
        // If bk_injectResetMethod was called, this will be fine.   If it hasn't
        // this will result in an infinite loop.
        class_replaceMethod(self,
                            injectSelector,
                            imp_implementationWithBlock(internalBlock),
                            method_getTypeEncoding(origMethod));
    }
    else
    {
        class_addMethod(self,
                        injectSelector,
                        imp_implementationWithBlock(internalBlock),
                        method_getTypeEncoding(origMethod));
    }

    method_exchangeImplementations(class_getInstanceMethod(self, selector), class_getInstanceMethod(self, injectSelector));

    return YES;
}

+ (NSInvocation *)bk_invocationWithSignature:(NSMethodSignature *)signature target:(id)target selector:(SEL)selector andArgs:(va_list)args
{
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    for (NSUInteger i = 2; i < [signature numberOfArguments]; i++)
    {
        const char *argType = [signature getArgumentTypeAtIndex:i];
        NSUInteger bufferSize = 0;
        NSGetSizeAndAlignment(argType, &bufferSize, NULL);

        // 32 bit simulator has a bug with the (ugly) and cross-platform method of assigning args.
        // It does however have a simple, non-cross-platform method of doing it.
#if TARGET_IPHONE_SIMULATOR && __LP64__ == NO
        [invocation setArgument:args atIndex:i ];

        args += MAX(MIN_ARG_SIZE,bufferSize);
#else
        // This makes me cry.  Many holes and huge/ugly
        if (NO) {}
        assignArgumentIf(bool, int, argType, args, i)
        assignArgumentIf(BOOL, int, argType, args, i)
        assignArgumentIf(id, id, argType, args, i)
        assignArgumentIf(SEL, SEL, argType, args, i)
        assignArgumentIf(Class, Class, argType, args, i)
        assignArgumentIf(char, int, argType, args, i)
        assignArgumentIf(const char*, int*, argType, args, i)
        assignArgumentIf(unsigned char, int, argType, args, i)
        assignArgumentIf(int, int, argType, args, i)
        assignArgumentIf(short, int, argType, args, i)
        assignArgumentIf(unichar, int, argType, args, i)
        assignArgumentIf(float, double, argType, args, i)
        assignArgumentIf(double, double, argType, args, i)
        assignArgumentIf(long, long, argType, args, i)
        assignArgumentIf(long long, long long, argType, args, i)
        assignArgumentIf(unsigned int, unsigned int, argType, args, i)
        assignArgumentIf(unsigned long, unsigned long, argType, args, i)
        assignArgumentIf(unsigned long long, unsigned long long, argType, args, i)
        assignArgumentIf(char*, char*, argType, args, i)
        assignArgumentIf(void*, void*, argType, args, i)
        assignArgumentIf(CGPoint, CGPoint, argType, args, i)
        assignArgumentIf(CGRect, CGRect, argType, args, i)
        else
        {
            [NSException raise:NSInvalidArgumentException format:@"Unknown type encoding %@", [NSString stringWithCString:argType encoding:NSASCIIStringEncoding]];
        }
#endif
    }
    [invocation setTarget:target];
    [invocation setSelector:selector];
    return invocation;
}


+ (BOOL)bk_injectResetMethod:(SEL)selector
{
    Method origMethod = class_getInstanceMethod(self, selector);
    if (!origMethod)
    {
        return NO;
    }
    
    SEL injectSelector = NSSelectorFromString([@"bk_injectMethod_before_after__" stringByAppendingString:NSStringFromSelector(selector)]);
    Method injectMethod = class_getInstanceMethod(self, injectSelector);
    if (!injectMethod)
    {
        return NO;
    }
    
    method_exchangeImplementations(injectMethod, origMethod);
    
    return YES;
}

@end
