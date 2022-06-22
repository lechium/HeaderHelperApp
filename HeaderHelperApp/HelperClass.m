//
//  HelperClass.m
//  HeaderHelperApp
//
//  Created by Kevin Bradley on 5/31/19.
//  Copyright © 2019 nito. All rights reserved.
//

#import "HelperClass.h"
#import "classdump.h"

#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

@implementation NSString (extra)

- (id)dictionaryRepresentation {
    NSString *error = nil;
    NSPropertyListFormat format;
    NSData *theData = [self dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    id theDict = [NSPropertyListSerialization propertyListFromData:theData
                                                  mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                                            format:&format
                                                  errorDescription:&error];
    return theDict;
}

@end

@implementation HelperClass

- (void)getFileEntitlementsOnMainThread:(NSString *)inputFile withCompletion:(void(^)(NSString *entitlements))block {
    //NSLog(@"checking file: %@", inputFile);
    if (![[NSFileManager defaultManager] fileExistsAtPath:inputFile]){
        //NSLog(@"file doesnt exist: %@", inputFile);
        if (block){
            block(nil);
        }
        return;
    }
    NSString *fileContents = [NSString stringWithContentsOfFile:inputFile encoding:NSASCIIStringEncoding error:nil];
    NSUInteger fileLength = [fileContents length];
    if (fileLength == 0) {
        fileContents = [NSString stringWithContentsOfFile:inputFile]; //if ascii doesnt work, have to use the deprecated (thankfully not obsolete!) method
    }
    fileLength = [fileContents length];
    if (fileLength == 0){
        if (block){
            NSLog(@"file length is 0, failed: %@", inputFile);
            block(nil);
            return;
        }
    }
    NSScanner *theScanner;
    NSString *text = nil;
    NSString *returnText = nil;
    theScanner = [NSScanner scannerWithString:fileContents];
    while ([theScanner isAtEnd] == NO) {
        [theScanner scanUpToString:@"<?xml" intoString:NULL];
        [theScanner scanUpToString:@"</plist>" intoString:&text];
        text = [text stringByAppendingFormat:@"</plist>"];
        //NSLog(@"text: %@", [text dictionaryRepresentation]);
        NSDictionary *dict = [text dictionaryRepresentation];
        if (dict && [dict allKeys].count > 0) {
            if (![[dict allKeys] containsObject:@"CFBundleIdentifier"] && ![[dict allKeys] containsObject:@"cdhashes"]){
                //NSLog(@"got im: %@", [[inputFile lastPathComponent] stringByDeletingPathExtension]);
                returnText = text;
                break;
            }
        } else {
            NSLog(@"no entitlements found: %@", inputFile);
        }
    }
    if (block){
        block(returnText);
    }
}

- (void)getFileEntitlements:(NSString *)inputFile withCompletion:(void(^)(NSString *entitlements))block {
    //NSLog(@"checking file: %@", inputFile.lastPathComponent);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if (![[NSFileManager defaultManager] fileExistsAtPath:inputFile]){
            //NSLog(@"file doesnt exist: %@", inputFile);
            if (block){
                block(nil);
            }
            return;
        }
        NSString *fileContents = [NSString stringWithContentsOfFile:inputFile encoding:NSASCIIStringEncoding error:nil];
        NSUInteger fileLength = [fileContents length];
        if (fileLength == 0) {
            fileContents = [NSString stringWithContentsOfFile:inputFile]; //if ascii doesnt work, have to use the deprecated (thankfully not obsolete!) method
        }
        fileLength = [fileContents length];
        if (fileLength == 0){
            if (block){
                block(nil);
                return;
            }
        }
        NSScanner *theScanner;
        NSString *text = nil;
        NSString *returnText = nil;
        theScanner = [NSScanner scannerWithString:fileContents];
        while ([theScanner isAtEnd] == NO) {
            [theScanner scanUpToString:@"<?xml" intoString:NULL];
            [theScanner scanUpToString:@"</plist>" intoString:&text];
            text = [text stringByAppendingFormat:@"</plist>"];
            //NSLog(@"text: %@", [text dictionaryRepresentation]);
            NSDictionary *dict = [text dictionaryRepresentation];
            if (dict && [dict allKeys].count > 0) {
                if (![[dict allKeys] containsObject:@"CFBundleIdentifier"] && ![[dict allKeys] containsObject:@"cdhashes"]){
                    //NSLog(@"got im: %@", [[inputFile lastPathComponent] stringByDeletingPathExtension]);
                    returnText = text;
                    break;
                }
            } else {
                NSLog(@"no entitlements found: %@", inputFile);
            }
        }
        if (block){
            block(returnText);
        }
    });
}


- (void)processRootFolder:(NSString *)rootFolder {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSString *outputFolder = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop/export"];
        NSFileManager *man = [NSFileManager defaultManager];
        if (![man fileExistsAtPath:outputFolder]){
            [man createDirectoryAtPath:outputFolder withIntermediateDirectories:true attributes:nil error:nil];
        }
        NSArray *paths = [self rawDaemonPathsForPath:rootFolder];
        NSLog(@"%@", paths);
        NSString *entOutput = [outputFolder stringByAppendingPathComponent:@"Entitlements"];
        if (![man fileExistsAtPath:entOutput]){
            [man createDirectoryAtPath:entOutput withIntermediateDirectories:true attributes:nil error:nil];
        }
        [paths enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *fullFilePath = [rootFolder stringByAppendingPathComponent:obj];
            [self getFileEntitlementsOnMainThread:fullFilePath withCompletion:^(NSString *entitlements) {
                if (entitlements) {
                    NSString *fileName = [[entOutput stringByAppendingPathComponent:[obj lastPathComponent]] stringByAppendingPathExtension:@"plist"];
                    //NSLog(@"valid ents for %@ writing to file: %@", [obj lastPathComponent], fileName);
                    [entitlements writeToFile:fileName atomically:true encoding:NSUTF8StringEncoding error:nil];
                }
            }];
        }];
        
        //done with daemons et al
        
        NSArray *exportPaths = @[@"Applications", @"System/Library/Frameworks", @"System/Library/PrivateFrameworks"];
        [exportPaths enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [self classDumpBundlesInFolder:[rootFolder stringByAppendingPathComponent:obj] toPath:[outputFolder stringByAppendingPathComponent:obj]];
        }];
        //NSString *outputFile = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop/daemons.plist"];
        //[rawDaemonDetails writeToFile:outputFile atomically:true];
    });
}

- (void)doStuffWithFile:(NSString *)file {
    NSString *outputFolder = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop/HHT"];
    [[NSFileManager defaultManager] createDirectoryAtPath:outputFolder withIntermediateDirectories:true attributes:nil error:nil];
    NSLog(@"performing class dump on file: %@ to folder: %@", file, outputFolder);
    [classdump performClassDumpOnFile:file toFolder:outputFolder];
}

- (void)classDumpBundlesInFolder:(NSString *)folderPath toPath:(NSString *)outputPath{
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSFileManager *man = [NSFileManager defaultManager];
        NSArray *dirContents = [man contentsOfDirectoryAtPath:folderPath error:nil];
        //NSString *lastPath = [folderPath lastPathComponent];
        //NSString *outputPath = [folderPath stringByAppendingPathComponent:lastPath];
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
            
            //NSString *classDumpPath = [[NSBundle mainBundle] pathForResource:@"classdumpios" ofType:@""];
            
            //NSString *runLine = [NSString stringWithFormat:@"%@ -a -A -H -o '%@' '%@'",classDumpPath, headerPath, exePath];
            //NSLog(@"%@", runLine);
            //[self runCommand: runLine];
            //class-dump -a -A -H -I -o PrivateHeaders
            //
            NSLog(@"[%lu of %lu] Dumping bundle: %@ ...", idx, dirContents.count, exePath.lastPathComponent);
            [classdump performClassDumpOnFile:exePath toFolder:headerPath];
        }];
        NSLog(@"Finished: %@", folderPath);
    });
}

+ (NSArray *)arrayReturnForTask:(NSString *)taskBinary withArguments:(NSArray *)taskArguments {
    NSLog(@"%@ %@", taskBinary, [taskArguments componentsJoinedByString:@" "]);
    NSTask *task = [[NSTask alloc] init];
    NSPipe *pipe = [[NSPipe alloc] init];
    NSFileHandle *handle = [pipe fileHandleForReading];
    [task setLaunchPath:taskBinary];
    [task setArguments:taskArguments];
    [task setStandardOutput:pipe];
    [task setStandardError:pipe];
    [task launch];
    NSData *outData = nil;
    NSString *temp = nil;
    while((outData = [handle readDataToEndOfFile]) && [outData length]) {
        temp = [[NSString alloc] initWithData:outData encoding:NSASCIIStringEncoding];
    }
    [handle closeFile];
    task = nil;
    return [temp componentsSeparatedByString:@"\n"];
}


+ (NSArray *)returnForProcess:(NSString *)call {
    if (call==nil)
        return 0;
    char line[200];
    NSLog(@"running process: %@", call);
    FILE* fp = popen([call UTF8String], "r");
    NSMutableArray *lines = [[NSMutableArray alloc]init];
    if (fp) {
        while (fgets(line, sizeof line, fp)) {
            NSString *s = [NSString stringWithCString:line encoding:NSUTF8StringEncoding];
            s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            [lines addObject:s];
        }
    }
    pclose(fp);
    return lines;
}

- (NSArray *)rawDaemonPathsForPath:(NSString *)path {
    NSArray *fullDaemonList = [HelperClass rawDaemonListAtPath:path];
    __block NSMutableArray *programList = [NSMutableArray new];
    [fullDaemonList enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ([[obj pathExtension] isEqualToString:@"plist"]){
            NSDictionary *dirtyDeeds = [NSDictionary dictionaryWithContentsOfFile:obj];
            if (dirtyDeeds){
                NSString *programPath = nil;
                if ([[dirtyDeeds allKeys] containsObject:@"Program"]){
                    programPath = dirtyDeeds[@"Program"];
                    //NSLog(@"program: %@", programPath);
                } else if ([[dirtyDeeds allKeys] containsObject:@"ProgramArguments"]){
                    programPath = [dirtyDeeds[@"ProgramArguments"] firstObject];
                    //NSLog(@"program: %@", programPath);
                }
                //NSLog(@"dictKey: %@", dictKey);
                if (programPath != nil){
                    [programList addObject:programPath];
                }
            }
        }
    }];
    return programList;
}

- (NSDictionary *)rawDaemonDetailsForPath:(NSString *)path {
    
    NSArray *fullDaemonList = [HelperClass rawDaemonListAtPath:path];
    
    //NSLog(@"fullDaemonList: %@", fullDaemonList);
    NSMutableDictionary *finalDict = [NSMutableDictionary new];
    [fullDaemonList enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ([[obj pathExtension] isEqualToString:@"plist"]){
            NSDictionary *dirtyDeeds = [NSDictionary dictionaryWithContentsOfFile:obj];
            if (dirtyDeeds){
                NSString *dictKey = nil;
                if ([[dirtyDeeds allKeys] containsObject:@"Program"]){
                    dictKey = [dirtyDeeds[@"Program"] lastPathComponent];
                    NSLog(@"program: %@", dirtyDeeds[@"Program"]);
                } else if ([[dirtyDeeds allKeys] containsObject:@"ProgramArguments"]){
                    dictKey = [[dirtyDeeds[@"ProgramArguments"] firstObject] lastPathComponent];
                    NSLog(@"program: %@", [dirtyDeeds[@"ProgramArguments"] firstObject]);
                }
                //NSLog(@"dictKey: %@", dictKey);
                if (dictKey != nil && dirtyDeeds != nil){
                    finalDict[dictKey] = dirtyDeeds;
                }
                
            }
            
        }
    }];
    return finalDict;
}

+ (NSArray *)rawDaemonListAtPath:(NSString *)path {
    
    NSString *task = @"/usr/bin/find";
    NSArray *returnValue = [self arrayReturnForTask:task withArguments:@[path, @"-name", @"com.*.plist"]];
    //NSLog(@"find return: %@", returnValue);
    return returnValue;
}

- (int)runCommand:(NSString *)call {
    if (call==nil)
        return 0;
    char line[200];
    NSLog(@"running process: %@", call);
    FILE* fp = popen([call UTF8String], "r");
    NSMutableArray *lines = [[NSMutableArray alloc]init];
    if (fp) {
        while (fgets(line, sizeof line, fp)) {
            NSString *s = [NSString stringWithCString:line encoding:NSUTF8StringEncoding];
            s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            [lines addObject:s];
        }
    }
    int returnStatus = pclose(fp);
    return returnStatus;
}

@end
