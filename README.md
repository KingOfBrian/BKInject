BKInject
========

BKInject is a project to inject blocks before and after a method executes to help in debugging applications.
In general, it's a bad idea to use this for anything else.

Usage
=====
The usage is pretty simple, however I haven't found a universal way of dealing with variable in a
universal manner, without va_list.   Implementation ideas are appretiated!

     [UIView bk_injectMethod:@selector(willMoveToSuperview:) before:^(UIView *instance, ...) {
        va_list args;
        va_start(args, instance);
        
        UIView *superview = va_arg(args, UIView *);
        va_end(args);
        NSLog(@"%@ moving to superview %@", instance, superview);
    } after:^(UIView *instance, ...) {
    }];
    

For more usage, check out the unit tests.


