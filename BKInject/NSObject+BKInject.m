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



@implementation NSObject (BKInject)

+ (void)bk_invokeBlock:(BKInjectBlock)block target:(id)target arguments:(va_list)args count:(NSUInteger)count
{
    // Not a fan.
    switch (count) {
        case 0:block(target);break;
        case 1:block(target, va_arg(args, void*));break;
        case 2:block(target, va_arg(args, void*), va_arg(args, void*));break;
        case 3:block(target, va_arg(args, void*), va_arg(args, void*), va_arg(args, void*));break;
        case 4:block(target, va_arg(args, void*), va_arg(args, void*), va_arg(args, void*), va_arg(args, void*));break;
        case 5:block(target, va_arg(args, void*), va_arg(args, void*), va_arg(args, void*), va_arg(args, void*), va_arg(args, void*));break;
        case 6:block(target, va_arg(args, void*), va_arg(args, void*), va_arg(args, void*), va_arg(args, void*), va_arg(args, void*), va_arg(args, void*));break;
        default:
            [NSException raise:NSInvalidArgumentException format:@"More than 6 arguments?  Really?!  Fix this!"];
            break;
    }
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
        BKInjectBlock voidBlock = ^(NSObject *target, ...)
        {
            va_list args;
            va_start(args, target);
            
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setTarget:target];
            [invocation setSelector:injectSelector];
            
            for (NSUInteger i = 2; i < [signature numberOfArguments]; i++)
            {
                void* argument = va_arg(args, void*);
                [invocation setArgument:&argument atIndex:i];
            }
            va_end(args);
            
            if (before)
            {
                va_start(args, target);
                [self bk_invokeBlock:before target:target arguments:args count:[signature numberOfArguments] - 2];
                va_end(args);
            }
            
            [invocation invoke];
            
            if (after)
            {
                va_start(args, target);
                [self bk_invokeBlock:after target:target arguments:args count:[signature numberOfArguments] - 2];
                va_end(args);
            }
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
            
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setTarget:target];
            [invocation setSelector:injectSelector];
            
            for (NSUInteger i = 2; i < [signature numberOfArguments]; i++)
            {
                void* argument = va_arg(args, void*);
                [invocation setArgument:&argument atIndex:i];
            }
            va_end(args);
            
            if (before)
            {
                va_start(args, target);
                [self bk_invokeBlock:before target:target arguments:args count:[signature numberOfArguments] - 2];
                va_end(args);
            }
            
            [invocation invoke];
            
            if (after)
            {
                va_start(args, target);
                [self bk_invokeBlock:after target:target arguments:args count:[signature numberOfArguments] - 2];
                va_end(args);
            }
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

@end
