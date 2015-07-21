//
//  LPBackdoorRoute.m
//  calabash
//
//  Created by Karl Krukow on 08/04/12.
//  Copyright (c) 2012 LessPainful. All rights reserved.
//
#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import "LPBackdoorRoute.h"
#import "LPCocoaLumberjack.h"

@implementation LPBackdoorRoute

- (BOOL) supportsMethod:(NSString *) method atPath:(NSString *) path {
  return [method isEqualToString:@"POST"];
}

- (NSDictionary *) JSONResponseForMethod:(NSString *) method URI:(NSString *) path data:(NSDictionary *) data {
  NSString *originalSelStr = [data objectForKey:@"selector"];
  NSString *selectorName = originalSelStr;
  if (![originalSelStr hasSuffix:@":"]) {
    LPLogWarn(@"Selector name is missing a ':'");
    LPLogWarn(@"All backdoor methods must take at least one argument.");
    LPLogWarn(@"Appending a ':' to the selector name.");
    LPLogWarn(@"This will be an error in the future.");
    selectorName = [selectorName stringByAppendingString:@":"];
  }

  id argument = [data objectForKey:@"arg"];
  if (!argument) {
    LPLogError(@"Expected data dictionary to contain an 'arg' key");
    LPLogError(@"data = '%@'", data);
    NSString *details = [NSString stringWithFormat:@"Expected backdoor selector '%@' to have an argument, but found no 'arg' key in data '%@'",
                         selectorName, data];

    NSString *reason = [NSString stringWithFormat:@"Missing argument for selector: '%@'",
                        selectorName];
    return @{ @"details" : details, @"reason" : reason, @"outcome" : @"FAILURE" };
  }

  SEL selector = NSSelectorFromString(selectorName);
  id<UIApplicationDelegate> delegate = [[UIApplication sharedApplication] delegate];
  if ([delegate respondsToSelector:selector]) {
    id result = nil;

    NSMethodSignature *methodSignature;
    methodSignature = [[delegate class] instanceMethodSignatureForSelector:selector];

    NSInvocation *invocation;
    invocation = [NSInvocation invocationWithMethodSignature:methodSignature];

    [invocation setSelector:selector];
    [invocation setArgument:&argument atIndex:2];

    [invocation retainArguments];

    if ([[NSThread currentThread] isMainThread]) {
      [invocation invokeWithTarget:delegate];
    } else {
      [invocation performSelectorOnMainThread:@selector(invokeWithTarget:)
                                   withObject:delegate
                                   waitUntilDone:YES];
    }

    void *buffer;

    [invocation getReturnValue:&buffer];

    result = (__bridge id)buffer;

    if (!result) {result = [NSNull null];}
    return
    @{
      @"results": result,
      // Legacy API:  Starting in Calabash 2.0 and Calabash 0.15.0, the 'result'
      // key will be dropped.
      @"result" : result,
      @"outcome" : @"SUCCESS"
      };

  } else {

    NSArray *lines =
    @[
      @"",
      [NSString stringWithFormat:@"You must define '%@' in your UIApplicationDelegate.",
       selectorName],
      @"",
      [NSString stringWithFormat:@"// Example"],
      [NSString stringWithFormat:@"-(NSString *)%@(NSString *)argument {", selectorName],
      [NSString stringWithFormat:@"  // do stuff here"],
      [NSString stringWithFormat:@"  return @\"a result\";"],
      [NSString stringWithFormat:@"}"],
      @"",
      @"// Documentation",
      @"http://developer.xamarin.com/guides/testcloud/calabash/working-with/backdoors/#backdoor_in_iOS",
      @"",
      @""
      ];

    NSString *details = [lines componentsJoinedByString:@"\n"];

    NSString *reason = [NSString stringWithFormat:@"The backdoor: '%@' is undefined.",
                        selectorName];
    return  @{ @"details" : details, @"reason" : reason, @"outcome" : @"FAILURE" };
  }
}

@end
