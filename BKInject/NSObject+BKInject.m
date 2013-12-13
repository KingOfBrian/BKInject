//
//  NSObject+BKInject.m
//  Cocoplora
//
//  Created by Brian King on 12/12/13.
//  Copyright (c) 2013 King Software Designs. All rights reserved.
//

#import "NSObject+BKInject.h"

#if TARGET_OS_IPHONE
  #import <objc/runtime.h>
  #import <objc/message.h>
#else
  #import <objc/objc-class.h>
#endif

typedef void (^BKInjectBlockInternal)(id self, ...);


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

+ (BOOL)bk_injectMethod:(SEL)selector before:(BKInjectBlock)before after:(BKInjectBlock)after
{
    Method origMethod = class_getInstanceMethod(self, selector);
    if (!origMethod) {
        return NO;
    }
    // Add an over-ride of the method to this class.
    class_addMethod(self,
                    selector,
                    class_getMethodImplementation(self, selector),
                    method_getTypeEncoding(origMethod));
    
    SEL injectSelector = NSSelectorFromString([@"bk_injectMethod_before_after__" stringByAppendingString:NSStringFromSelector(selector)]);

    BKInjectBlockInternal internal = ^(NSObject *target, ...)
    {
        va_list args;
        va_start(args, target);

        NSMethodSignature *signature = [self.class instanceMethodSignatureForSelector:injectSelector];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setTarget:target];
        [invocation setSelector:injectSelector];
        [invocation retainArguments];
        
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
    
    class_addMethod(self,
                    injectSelector,
                    imp_implementationWithBlock(internal),
                    method_getTypeEncoding(origMethod));

    method_exchangeImplementations(class_getInstanceMethod(self, selector), class_getInstanceMethod(self, injectSelector));

    return YES;
}

@end
