//
//  BKInjectTests.m
//  BKInjectTests
//
//  Created by Brian King on 12/12/13.
//  Copyright (c) 2013 Brian King. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSObject+BKInject.h"
#import <QuartzCore/QuartzCore.h>

@interface Foo : NSObject
@property (copy) NSString *value;
- (void)populateValueWithFoo;
- (void)thisMethod:(NSString *)arg1 hasTwoArgs:(NSString *)args2;
- (void)primitiveMethod:(NSUInteger)i;
- (NSUInteger)primativeReturnMethod;
@end

@implementation Foo

- (void)populateValueWithFoo
{
    NSString *fooValue = [@"FOO" copy];
    self.value = fooValue;
}
- (void)thisMethod:(NSString *)arg1 hasTwoArgs:(NSString *)arg2
{
    self.value = [arg1 stringByAppendingString:arg2];
}

- (void)primitiveMethod:(NSUInteger)i
{
    self.value = [NSString stringWithFormat:@"P%zd", i];
}

- (void)largePrimitiveValue:(CGRect)rect
{
    self.value = [NSString stringWithFormat:@"R%f.%f / %fx%f", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height];
}

- (NSUInteger)primativeReturnMethod
{
    return 88;
}
- (void)testBool:(BOOL)a float:(float)b int:(NSUInteger)c rect:(CGRect)d string:(NSString *)e selector:(SEL)f point:(CGPoint)g char:(const char *)h
{
}


@end

@interface BKInjectTests : XCTestCase

@end

@implementation BKInjectTests

- (void)testInjectNoArg
{
    __block NSString *preValue = nil;
    __block NSString *postValue = nil;
    
    [Foo bk_injectMethod:@selector(populateValueWithFoo) before:^(NSInvocation *invocation) {
        Foo *instance = invocation.target;
        preValue = instance.value;
    } after:^(NSInvocation *invocation) {
        Foo *instance = invocation.target;
        postValue = instance.value;
    }];
    
    Foo *f = [[Foo alloc] init];
    [f populateValueWithFoo];
    XCTAssertTrue(preValue == nil, @"");
    XCTAssertTrue([postValue isEqualToString:@"FOO"], @"");
    
    [Foo bk_injectResetMethod:@selector(populateValueWithFoo)];
    postValue = nil;
    [f populateValueWithFoo];
    XCTAssertTrue(postValue == nil, @"");
}

- (void)testInjectOneArg
{
    __block NSString *preValue = nil;
    __block NSString *postValue = nil;
    
    [Foo bk_injectMethod:@selector(setValue:) before:^(NSInvocation *invocation) {
        [invocation getArgument:&preValue atIndex:2];
    } after:^(NSInvocation *invocation) {
        Foo *instance = invocation.target;
        postValue = instance.value;
    }];
    
    Foo *f = [[Foo alloc] init];
    f.value = @"FOO";
    XCTAssertTrue([preValue isEqualToString:@"FOO"], @"");
    XCTAssertTrue([postValue isEqualToString:@"FOO"], @"");
    
    [Foo bk_injectResetMethod:@selector(setValue:)];
}

- (void)testInjectTwoArg
{
    __block NSString *tmpValue = nil;
    __block NSString *preValue = nil;
    __block NSString *postValue = nil;
    
    [Foo bk_injectMethod:@selector(thisMethod:hasTwoArgs:) before:^(NSInvocation *invocation) {
        [invocation getArgument:&preValue atIndex:2];
        [invocation getArgument:&tmpValue atIndex:3];
        
        preValue = [preValue stringByAppendingString:tmpValue];

    } after:^(NSInvocation *invocation) {
        [invocation getArgument:&postValue atIndex:2];
        [invocation getArgument:&tmpValue atIndex:3];
        
        postValue = [postValue stringByAppendingString:tmpValue];
    }];
    
    Foo *f = [[Foo alloc] init];
    [f thisMethod:@"FOO" hasTwoArgs:@"BAR"];
    XCTAssertTrue([preValue isEqualToString:@"FOOBAR"], @"");
    XCTAssertTrue([postValue isEqualToString:@"FOOBAR"], @"");
    
    [Foo bk_injectResetMethod:@selector(thisMethod:hasTwoArgs:)];
}

- (void)testInjectPrimitive
{
    __block NSUInteger preInteger = NSNotFound;
    __block NSUInteger postInteger = NSNotFound;
    __block NSString *preValue = nil;
    __block NSString *postValue = nil;
    
    [Foo bk_injectMethod:@selector(primitiveMethod:) before:^(NSInvocation *invocation) {
        Foo *instance = invocation.target;
        [invocation getArgument:&preInteger atIndex:2];
        
        preValue = instance.value;
    } after:^(NSInvocation *invocation) {
        Foo *instance = invocation.target;
        [invocation getArgument:&postInteger atIndex:2];
       
        postValue = instance.value;
    }];
    
    Foo *f = [[Foo alloc] init];
    [f primitiveMethod:7];
    XCTAssertTrue(preInteger == 7 && postInteger == 7, @"");
    XCTAssertTrue([f.value isEqualToString:@"P7"], @"");
    XCTAssertTrue(preValue == nil, @"");
    XCTAssertTrue([postValue isEqualToString:@"P7"], @"");
    
    [Foo bk_injectResetMethod:@selector(primitiveMethod:)];
}

- (void)testInjectLargePrimitive
{
    __block CGRect preRect = CGRectZero;
    __block CGRect postRect = CGRectZero;
    
    [Foo bk_injectMethod:@selector(largePrimitiveValue:) before:^(NSInvocation *invocation) {
        [invocation getArgument:&preRect atIndex:2];
    } after:^(NSInvocation *invocation) {
        [invocation getArgument:&postRect atIndex:2];
    }];
    
    Foo *f = [[Foo alloc] init];
    [f largePrimitiveValue:CGRectMake(1, 2, 3, 4)];
    XCTAssertTrue(preRect.origin.x == 1 &&
                  preRect.origin.y == 2 &&
                  preRect.size.width == 3 &&
                  preRect.size.height == 4, @"");

    [Foo bk_injectResetMethod:@selector(largePrimitiveValue:)];

}

- (void)testReturnObject
{
    __block BOOL preEnter = NO;
    __block BOOL postEnter = NO;
    
    [Foo bk_injectMethod:@selector(value) before:^(NSInvocation *invocation) {
        preEnter = YES;
    } after:^(NSInvocation *invocation) {
        postEnter = YES;
    }];
    
    Foo *f = [[Foo alloc] init];
    f.value = @"FOO";
    XCTAssertTrue(preEnter == NO, @"");
    XCTAssertTrue(postEnter == NO, @"");
    XCTAssertTrue([f.value isEqualToString:@"FOO"], @"");
    XCTAssertTrue(preEnter, @"");
    XCTAssertTrue(postEnter, @"");
    [Foo bk_injectResetMethod:@selector(value)];
}

- (void)testReturnPrimative
{
    __block BOOL preEnter = NO;
    __block BOOL postEnter = NO;
    
    [Foo bk_injectMethod:@selector(primativeReturnMethod) before:^(NSInvocation *invocation) {
        preEnter = YES;
    } after:^(NSInvocation *invocation) {
        postEnter = YES;
    }];
    
    Foo *f = [[Foo alloc] init];
    XCTAssertTrue(preEnter == NO, @"");
    XCTAssertTrue(postEnter == NO, @"");
    XCTAssertTrue([f primativeReturnMethod] == 88, @"");
    XCTAssertTrue(preEnter, @"");
    XCTAssertTrue(postEnter, @"");
    
    [Foo bk_injectResetMethod:@selector(primativeReturnMethod)];
}

- (void)testReInjection
{
    __block BOOL preEnter = NO;
    __block BOOL postEnter = NO;
    
    [Foo bk_injectMethod:@selector(primativeReturnMethod) before:^(NSInvocation *invocation) {
        preEnter = YES;
    } after:^(NSInvocation *invocation) {
        postEnter = YES;
    }];
    
    Foo *f = [[Foo alloc] init];
    XCTAssertTrue(preEnter == NO, @"");
    XCTAssertTrue(postEnter == NO, @"");
    XCTAssertTrue([f primativeReturnMethod] == 88, @"");
    XCTAssertTrue(preEnter, @"");
    XCTAssertTrue(postEnter, @"");
    
    [Foo bk_injectResetMethod:@selector(primativeReturnMethod)];
    
    preEnter = NO;
    postEnter = NO;

    __block BOOL preEnter2 = NO;
    __block BOOL postEnter2 = NO;

    [Foo bk_injectMethod:@selector(primativeReturnMethod) before:^(NSInvocation *invocation) {
        preEnter2 = YES;
    } after:^(NSInvocation *invocation) {
        postEnter2 = YES;
    }];
    
    XCTAssertTrue(preEnter2 == NO, @"");
    XCTAssertTrue(postEnter2 == NO, @"");
    XCTAssertTrue([f primativeReturnMethod] == 88, @"");
    XCTAssertTrue(preEnter == NO, @"");
    XCTAssertTrue(postEnter == NO, @"");

    XCTAssertTrue(preEnter2, @"");
    XCTAssertTrue(postEnter2, @"");
    [Foo bk_injectResetMethod:@selector(primativeReturnMethod)];
}

- (void)testNilBullocks
{
    [Foo bk_injectMethod:@selector(primitiveMethod:) before:nil after:nil];
    Foo *f = [[Foo alloc] init];
    XCTAssertNoThrow([f primitiveMethod:7], @"");
    [Foo bk_injectResetMethod:@selector(primitiveMethod:)];
}

- (void)testArgumentsOfVariousTypes
{
    __block BOOL a;
    __block float b;
    __block NSUInteger c;
    __block CGRect d;
    __block NSString *e;
    __block SEL f;
    __block CGPoint g;
    __block const char *h;
    
    [Foo bk_injectMethod:@selector(testBool:float:int:rect:string:selector:point:char:) before:^(NSInvocation *invocation) {
        [invocation getArgument:&a atIndex:2];
        [invocation getArgument:&b atIndex:3];
        [invocation getArgument:&c atIndex:4];
        [invocation getArgument:&d atIndex:5];
        [invocation getArgument:&e atIndex:6];
        [invocation getArgument:&f atIndex:7];
        [invocation getArgument:&g atIndex:8];
        [invocation getArgument:&h atIndex:9];
    } after:^(NSInvocation *invocation) {
    }];
    
    Foo *foo = [[Foo alloc] init];
    [foo testBool:NO float:3.14159 int:7 rect:CGRectMake(1,2,3,4) string:@"Hey" selector:@selector(testNilBullocks) point:CGPointMake(10, 20) char:"1234"];

    XCTAssertTrue(a == NO && fabs(b - 3.14159) < 0.001 && c == 7, @"");
    XCTAssertTrue(d.origin.x == 1 &&
                  d.origin.y == 2 &&
                  d.size.width == 3 &&
                  d.size.height == 4, @"");
    XCTAssertTrue([e isEqualToString:@"Hey"], @"");
    XCTAssertTrue([NSStringFromSelector(f) isEqualToString:@"testNilBullocks"], @"");
    XCTAssertTrue(g.x == 10 && g.y == 20, @"");
    XCTAssertTrue(strcmp(h, "1234") == 0, @"");
    
    [Foo bk_injectResetMethod:@selector(testBool:float:int:rect:string:selector:point:char:)];

}

@end
