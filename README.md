BKInject
========

BKInject is a project to inject blocks before and after a method executes to help in debugging applications.
In general, it's a bad idea to use this for anything else.

Usage
=====
The usage is pretty simple:

     [UIView bk_injectMethod:@selector(willMoveToSuperview:) before:^(NSInvocation *invocation) {
        UIView *superview = nil;
        [invocation getArgument:&superview atIndex:2];

        NSLog(@"%@ moving to superview %@", invocation.target, superview);
    } after:^(NSInvocation *invocation) {
    }];
    



