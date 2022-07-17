//
//  HelperClass.h
//  HeaderHelperApp
//
//  Created by Kevin Bradley on 5/31/19.
//  Copyright © 2019 nito. All rights reserved.
//

#import <Foundation/Foundation.h>
#define DLog(format, ...) CFShow((__bridge CFStringRef)[NSString stringWithFormat:format, ## __VA_ARGS__]);

@interface HelperClass : NSObject
@property BOOL skipDaemons;
+ (id)sharedInstance;
- (void)classDumpBundlesInFolder:(NSString *)folderPath toPath:(NSString *)outputPath;
- (void)doStuffWithFile:(NSString *)file;
- (void)processRootFolder:(NSString *)rootFolder;
- (void)getFileEntitlements:(NSString *)inputFile withCompletion:(void(^)(NSString *entitlements))block;
- (void)getFileEntitlementsOnMainThread:(NSString *)inputFile withCompletion:(void(^)(NSString *entitlements))block;
- (NSArray *)findXcodes;
- (NSArray *)simRuntimes;
- (NSDictionary *)simRuntimesForXcode:(NSString *)xcode;
- (void)newGetFileEntitlementsOnMainThread:(NSString *)inputFile withCompletion:(void(^)(NSDictionary *entitlements))block;
@end


