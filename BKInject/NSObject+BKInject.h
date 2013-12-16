//
//  NSObject+BKInject.h
//
//  Created by Brian King on 12/12/13.
//  Copyright (c) 2013 Brian King. All rights reserved.
//

#import <Foundation/Foundation.h>
typedef void (^BKInjectBlock)(NSInvocation *invocation);

@interface NSObject (BKInject)

/*!
 * Swizzle the selector to execute the block before, before method execution, and after, after method execution.
 * Do not call this multiple times on the same selector, without reseting the method.
 */
+ (BOOL)bk_injectMethod:(SEL)selector before:(BKInjectBlock)before after:(BKInjectBlock)after;

/*!
 * Reset the selector back to the original implementation.   
 *
 * BUG: the before and after block are still retained by the old implementation.
 */
+ (BOOL)bk_injectResetMethod:(SEL)selector;

@end
