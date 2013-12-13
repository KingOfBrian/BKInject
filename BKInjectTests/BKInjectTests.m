//
//  BKInjectTests.m
//  BKInjectTests
//
//  Created by Brian King on 12/12/13.
//  Copyright (c) 2013 Brian King. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSObject+BKInject.h"

@interface Foo : NSObject
@property (copy) NSString *value;
- (void)populateValueWithFoo;
- (void)thisMethod:(NSString *)arg1 hasTwoArgs:(NSString *)args2;
- (void)primitiveMethod:(NSUInteger)i;
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

- (void)who:(id)a would:(id)b ever:(id)c write:(id)d methods:(id)e like:(id)f this:(id)g
{
    // ha
}


@end

@interface BKInjectTests : XCTestCase

@end

@implementation BKInjectTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInjectNoArg
{
    __block NSString *preValue = nil;
    __block NSString *postValue = nil;
    
    [Foo bk_injectMethod:@selector(populateValueWithFoo) before:^(Foo *instance, ...) {
        preValue = instance.value;
    } after:^(Foo *instance, ...) {
        postValue = instance.value;
    }];
    
    Foo *f = [[Foo alloc] init];
    [f populateValueWithFoo];
    XCTAssertTrue(preValue == nil, @"");
    XCTAssertTrue([postValue isEqualToString:@"FOO"], @"");
}

- (void)testInjectOneArg
{
    __block NSString *preValue = nil;
    __block NSString *postValue = nil;
    
    [Foo bk_injectMethod:@selector(setValue:) before:^(Foo *instance, ...) {
        va_list args;
        va_start(args, instance);
        
        preValue = (__bridge NSString *)va_arg(args, void*);
        va_end(args);
    } after:^(Foo *instance, ...) {
        postValue = instance.value;
    }];
    
    Foo *f = [[Foo alloc] init];
    f.value = @"FOO";
    XCTAssertTrue([preValue isEqualToString:@"FOO"], @"");
    XCTAssertTrue([postValue isEqualToString:@"FOO"], @"");
}

- (void)testInjectTwoArg
{
    __block NSString *preValue = nil;
    __block NSString *postValue = nil;
    
    [Foo bk_injectMethod:@selector(thisMethod:hasTwoArgs:) before:^(Foo *instance, ...) {
        va_list args;
        va_start(args, instance);
        
        preValue = (__bridge NSString *)va_arg(args, void*);
        preValue = [preValue stringByAppendingString:(__bridge NSString *)va_arg(args, void*)];
        va_end(args);
    } after:^(Foo *instance, ...) {
        va_list args;
        va_start(args, instance);
        
        postValue = (__bridge NSString *)va_arg(args, void*);
        postValue = [postValue stringByAppendingString:(__bridge NSString *)va_arg(args, void*)];
        va_end(args);
    }];
    
    Foo *f = [[Foo alloc] init];
    [f thisMethod:@"FOO" hasTwoArgs:@"BAR"];
    XCTAssertTrue([preValue isEqualToString:@"FOOBAR"], @"");
    XCTAssertTrue([postValue isEqualToString:@"FOOBAR"], @"");
}

- (void)testInjectPrimitive
{
    __block NSUInteger preInteger = NSNotFound;
    __block NSUInteger postInteger = NSNotFound;
    __block NSString *preValue = nil;
    __block NSString *postValue = nil;
    
    [Foo bk_injectMethod:@selector(primitiveMethod:) before:^(Foo *instance, ...) {
        va_list args;
        va_start(args, instance);
        
        preInteger = va_arg(args, NSUInteger);
        va_end(args);
        
        preValue = instance.value;
    } after:^(Foo *instance, ...) {
        va_list args;
        va_start(args, instance);
        
        postInteger = va_arg(args, NSUInteger);
        va_end(args);
        
        postValue = instance.value;
    }];
    
    Foo *f = [[Foo alloc] init];
    [f primitiveMethod:7];
    XCTAssertTrue(preInteger == 7 && postInteger == 7, @"");
    XCTAssertTrue([f.value isEqualToString:@"P7"], @"");
    XCTAssertTrue(preValue == nil, @"");
    XCTAssertTrue([postValue isEqualToString:@"P7"], @"");
}

- (void)testNilBullocks
{
    [Foo bk_injectMethod:@selector(primitiveMethod:) before:nil after:nil];
    Foo *f = [[Foo alloc] init];
    XCTAssertNoThrow([f primitiveMethod:7], @"");
}

- (void)testBadIdea
{
    [Foo bk_injectMethod:@selector(who:would:ever:write:methods:like:this:) before:^(Foo *instance, ...) {} after:^(Foo *instance, ...) {}];
    Foo *f = [[Foo alloc] init];
    XCTAssertThrows([f who:nil would:nil ever:nil write:nil methods:nil like:nil this:nil], @"");
}

@end
