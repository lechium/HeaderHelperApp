//
//  HelperClass.m
//  HeaderHelperApp
//
//  Created by Kevin Bradley on 5/31/19.
//  Copyright © 2019 nito. All rights reserved.
//

#import "HelperClass.h"

@implementation HelperClass

- (void)doStuffWithFolder:(NSString *)folderPath {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSFileManager *man = [NSFileManager defaultManager];
        NSArray *dirContents = [man contentsOfDirectoryAtPath:folderPath error:nil];
        NSString *lastPath = [folderPath lastPathComponent];
        NSString *outputPath = [folderPath stringByAppendingPathComponent:lastPath];
        [man createDirectoryAtPath:outputPath withIntermediateDirectories:TRUE attributes:nil error:nil];
        NSLog(@"dir contents: %@", dirContents);
        [dirContents enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            
            NSString *fullPath = [folderPath stringByAppendingPathComponent:obj];
            NSString *headerPath = [outputPath stringByAppendingPathComponent:[obj stringByDeletingPathExtension]];
            [man createDirectoryAtPath:headerPath withIntermediateDirectories:TRUE attributes:nil error:nil];
            NSString *plistPath = [fullPath stringByAppendingPathComponent:@"Info.plist"];
            NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:plistPath];
            NSString *exeName = dict[@"CFBundleExecutable"];
            NSString *exePath = [fullPath stringByAppendingPathComponent:exeName];
            
            NSString *classDumpPath = [[NSBundle mainBundle] pathForResource:@"classdumpios" ofType:@""];
            
            NSString *runLine = [NSString stringWithFormat:@"%@ -a -A -H -o '%@' '%@'",classDumpPath, headerPath, exePath];
            NSLog(@"%@", runLine);
            [self runCommand: runLine];
            //class-dump -a -A -H -I -o PrivateHeaders
            //
        }];
        
    });
}


- (int)runCommand:(NSString *)call
{
    if (call==nil)
        return 0;
    char line[200];
     NSLog(@"running process: %@", call);
    FILE* fp = popen([call UTF8String], "r");
    NSMutableArray *lines = [[NSMutableArray alloc]init];
    if (fp)
    {
        while (fgets(line, sizeof line, fp))
        {
            NSString *s = [NSString stringWithCString:line encoding:NSUTF8StringEncoding];
            s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            [lines addObject:s];
        }
    }
    int returnStatus = pclose(fp);
    return returnStatus;
}

@end
