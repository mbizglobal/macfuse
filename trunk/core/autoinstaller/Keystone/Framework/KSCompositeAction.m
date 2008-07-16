//
//  KSCompositeAction.m
//  Keystone
//
//  Created by Greg Miller on 1/29/08.
//  Copyright 2008 Google Inc. All rights reserved.
//

#import "KSCompositeAction.h"
#import "KSActionProcessor.h"
#import "KSActionPipe.h"
#import "GMLogger.h"
#import "GTMDefines.h"


@implementation KSCompositeAction

+ (id)actionWithActions:(NSArray *)actions {
  return [[[self alloc] initWithActions:actions] autorelease];
}

- (id)init {
  return [self initWithActions:nil];
}

- (id)initWithActions:(NSArray *)actions {
  if ((self = [super init])) {
    actions_ = [actions copy];
    subProcessor_ = [[KSActionProcessor alloc] initWithDelegate:self];
    completedActions_ = [[NSMutableArray alloc] init];
        
    if ([actions_ count] == 0) {
      GMLoggerDebug(@"can't create a composite action with no actions");
      [self release];
      return nil;
    }
  }
  return self;
}

- (void)dealloc {
  [actions_ release];
  [subProcessor_ setDelegate:nil];
  [subProcessor_ release];
  [completedActions_ release];
  [super dealloc];
}

- (NSArray *)actions {
  return actions_;
}

- (NSArray *)completedActions {
  // If the array is empty, return nil instead
  return [completedActions_ count] > 0 ? completedActions_ : nil;
}

- (BOOL)completedSuccessfully {
  return [actions_ isEqualToArray:completedActions_];
}

// All we do here is add all of the actions in |actions_| to our subProcessor_,
// then tell it to start processing.
- (void)performAction {
  _GTMDevAssert(subProcessor_ != nil, @"subProcessor must not be nil");
  
  KSAction *action = nil;
  NSEnumerator *actionEnumerator = [actions_ objectEnumerator];
  while ((action = [actionEnumerator nextObject])) {
    [subProcessor_ enqueueAction:action];
  }
  
  [subProcessor_ startProcessing];
}

- (void)terminateAction {
  [subProcessor_ stopProcessing];
  [[self processor] finishedProcessing:self successfully:NO];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@:%p actions=%@>",
          [self class], self, [self actions]];
}


//
// KSActionProcessor delegate methods.
// These callbacks will come from our |subProcessor_|
//

// Our subProcessor_ will call this method everytime one of its actions
// finishes. We watch these messages and record actions that complete 
// successfully, and if any do fail, we stop all processing and inform the 
// action processor that we (|self|) are running on that we have failed.
- (void)processor:(KSActionProcessor *)processor
   finishedAction:(KSAction *)action
     successfully:(BOOL)wasOK {
  // Make our outPipe contain the output of the last action. So, we'll just keep
  // replacing our outPipe contents with each action's outPipe contents as they
  // finish. Eventually we'll contain the output of the "last" one.
  [[self outPipe] setContents:[[action outPipe] contents]];
  if (wasOK) {
    [completedActions_ addObject:action];
  } else {
    GMLoggerInfo(@"Composite sub-action failed %@", action);
    // If some (any) action fails, then we abort the whole thing
    [subProcessor_ stopProcessing];
    [[self processor] finishedProcessing:self successfully:NO];
  }
}

// When our subProcessor is finished, then we are done ourselves.
- (void)processingDone:(KSActionProcessor *)processor {
  [[self processor] finishedProcessing:self successfully:YES];
}

@end
