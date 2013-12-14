//
//  NSObject+BKInject.h
//  Cocoplora
//
//  Created by Brian King on 12/12/13.
//  Copyright (c) 2013 King Software Designs. All rights reserved.
//

#import <Foundation/Foundation.h>
typedef void (^BKInjectBlock)(id self, ...);

@interface NSObject (BKInject)

+ (BOOL)bk_injectMethod:(SEL)selector before:(BKInjectBlock)before after:(BKInjectBlock)after;
+ (BOOL)bk_injectResetMethod:(SEL)selector;

@end
