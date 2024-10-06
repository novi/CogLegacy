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

- (BOOL)isFinished;

@end

@interface CogOperationQueue : NSObject

- (void)addOperation:(CogOperation *)op;

- (void)setMaxConcurrentOperationCount:(NSInteger)cnt;

- (void)waitUntilAllOperationsAreFinished;


@end

@interface CogInvocationOperation : CogOperation

- (id)initWithTarget:(id)target
                      selector:(SEL)sel
                        object:(id)arg;

- (id)result;

@end

typedef CogOperation NSOperation;
typedef CogOperationQueue NSOperationQueue;
typedef CogInvocationOperation NSInvocationOperation;