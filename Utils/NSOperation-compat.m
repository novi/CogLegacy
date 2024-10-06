//
//  NSOperation.m
//  Cog
//
//  Created by Yusuke Ito on 10/6/24.
//
//

#import "NSOperation-compat.h"

@implementation CogOperation

- (BOOL)isFinished
{
    NSAssert(false, @"TODO: 10.4");
    return NO;
}

@end

@implementation CogOperationQueue

- (void)addOperation:(CogOperation *)op
{
    
}

- (void)setMaxConcurrentOperationCount:(NSInteger)cnt
{
    
}

- (void)waitUntilAllOperationsAreFinished
{
    
}

@end

@implementation CogInvocationOperation

- (id)initWithTarget:(id)target
            selector:(SEL)sel
              object:(id)arg
{
    return [self init];
}

-(id)result
{
    return 0xdeadbeef;
}

@end