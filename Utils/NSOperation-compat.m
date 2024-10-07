//
//  NSOperation.m
//  Cog
//
//  Created by Yusuke Ito on 10/6/24.
//
//

#import "NSOperation-compat.h"
#import <unistd.h>

typedef enum {
	HasNoOperation = 0,
    HasOperation = 1
} WaitingOperation;

@implementation CogOperation

- (void)setFinished:(BOOL)f
{
    [self willChangeValueForKey:@"isFinished"];
    _isFinished = f;
    [self didChangeValueForKey:@"isFinished"];
}

- (BOOL)isFinished
{
    return _isFinished;
}

-(void)main
{
    
}

@end

@implementation CogOperationQueue

- (id)init
{
    self = [super init];
    if (self) {
        _lock = [[NSConditionLock alloc] initWithCondition:HasNoOperation];
        _queue = [[NSMutableArray alloc] init];
        [NSThread detachNewThreadSelector:@selector(backgroundThread:) toTarget:self withObject:nil];
    }
    return self;
}

- (void)addOperation:(CogOperation *)op
{
//    [_queue addObject:op];
//    [op performSelector:@selector(main)];
//    [op setFinished:YES];
    [_lock lock];
//    NSLog(@"operation added %@", op);
    [_queue addObject:op];
    [_lock unlockWithCondition:HasOperation];
}

- (void)setMaxConcurrentOperationCount:(NSInteger)cnt
{
    
}

- (void)backgroundThread:(id)arg
{
    while (YES) {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        [_lock lockWhenCondition:HasOperation];
        NSArray* ops = [_queue copy];
        [_queue removeAllObjects];
        _runningCount += ops.count;
        [_lock unlockWithCondition:HasNoOperation];
        NSEnumerator* enumerator = [ops objectEnumerator];
        NSOperation* op;
        while (op = [enumerator nextObject]) {
            [op main];
//            sleep(3);
//            NSLog(@"operation finished %@", op);
            [op setFinished:YES];
            _runningCount -= 1;
        }
        [pool release];
    }
}

- (void)waitUntilAllOperationsAreFinished
{
    while (_queue.count) {
        usleep(1000*10);
    }
    // TODO: synchronized
    while (_runningCount) {
        usleep(1000*10);
    }
}

@end


@implementation CogInvocationOperation


- (id)initWithTarget:(id)target
            selector:(SEL)sel
              object:(id)arg
{
    self = [super init];
    if (self) {
        NSMethodSignature* sig = [target methodSignatureForSelector:sel];
        _inv = [[NSInvocation invocationWithMethodSignature:sig] retain];
        _inv.target = target;
        _inv.selector = sel;
        if (sig.numberOfArguments > 2) {
            [_inv setArgument:&arg atIndex:2];
        }
        [_inv retainArguments];
    }
    return self;
}

-(id)result
{
    id result = nil;
    [_inv getReturnValue:&result];
    return result;
}

-(NSInvocation *)invocation
{
    return _inv;
}

-(void)main
{
    [_inv invoke];
}

- (void)dealloc
{
    [_inv release];
    _inv = nil;
    [super dealloc];
}

@end