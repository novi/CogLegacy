//
//  NSOperation.h
//  Cog
//
//  Created by Yusuke Ito on 10/6/24.
//
//

#import <Foundation/Foundation.h>
#import "NSInteger-compat.h"

@interface CogOperation : NSObject
{
    BOOL _isFinished;
}
- (BOOL)isFinished;
- (void)main;

@end

@interface CogOperationQueue : NSObject
{
    NSConditionLock* _lock;
    NSMutableArray* _queue;
    NSUInteger _runningCount;
}

- (void)addOperation:(CogOperation *)op;

- (void)setMaxConcurrentOperationCount:(NSInteger)cnt;

- (void)waitUntilAllOperationsAreFinished;


@end

@interface CogInvocationOperation : CogOperation
{
    NSInvocation* _inv;
}

- (id)initWithTarget:(id)target
                      selector:(SEL)sel
                        object:(id)arg;

- (id)result;

- (NSInvocation*)invocation;

@end

typedef CogOperation NSOperation;
typedef CogOperationQueue NSOperationQueue;
typedef CogInvocationOperation NSInvocationOperation;