//
//  HelperClass.h
//  HeaderHelperApp
//
//  Created by Kevin Bradley on 5/31/19.
//  Copyright © 2019 nito. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface HelperClass : NSObject

- (void)doStuffWithFolder:(NSString *)folderPath;
- (void)doStuffWithFile:(NSString *)file;
- (void)processRootFolder:(NSString *)rootFolder;
- (id)testGetEnts:(NSString *)inputFile;
- (void)getFileEntitlements:(NSString *)inputFile withCompletion:(void(^)(NSString *entitlements))block;
@end


