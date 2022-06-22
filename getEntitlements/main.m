//
//  main.m
//  getEntitlements
//
//  Created by Kevin Bradley on 6/22/22.
//  Copyright © 2022 nito. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HelperClass.h"
#define DLog(format, ...) CFShow((__bridge CFStringRef)[NSString stringWithFormat:format, ## __VA_ARGS__]);

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        
        //NSString *first = [NSString stringWithUTF8String:argv[0]];
        if (argc > 1){
            NSString *second = [NSString stringWithUTF8String:argv[1]];
            if ([[NSFileManager defaultManager] fileExistsAtPath:second]){
                HelperClass *hc = [HelperClass new];
                [hc getFileEntitlements:second withCompletion:^(NSString *entitlements) {
                    fprintf(stdout, "%s\n", [entitlements UTF8String]);
                    //DLog(@"%@", entitlements);
                    exit(0);
                }];
            }
            //DLog(@"second: %@", second);
        } else {
            exit(0);
        }
    }
    CFRunLoopRun();
    return 0;
}
