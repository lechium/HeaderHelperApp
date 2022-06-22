//
//  HelperClass.m
//  HeaderHelperApp
//
//  Created by Kevin Bradley on 5/31/19.
//  Copyright © 2019 nito. All rights reserved.
//

#import "HelperClass.h"
#import "classdump.h"

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

- (void)getFileEntitlements:(NSString *)inputFile withCompletion:(void(^)(NSString *entitlements))block {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSString *fileContents = [NSString stringWithContentsOfFile:inputFile encoding:NSASCIIStringEncoding error:nil];
        NSUInteger fileLength = [fileContents length];
        if (fileLength == 0) {
            fileContents = [NSString stringWithContentsOfFile:inputFile]; //if ascii doesnt work, have to use the deprecated (thankfully not obsolete!) method
        }
        fileLength = [fileContents length];
        if (fileLength == 0){
            if (block){
                block(nil);
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
                    returnText = text;
                    break;
                }
            }
        }
        if (block){
            block(returnText);
        }
    });
}

- (id)testGetEnts:(NSString *)inputFile {
    NSString *fileContents = [NSString stringWithContentsOfFile:inputFile encoding:NSASCIIStringEncoding error:nil];
    NSUInteger fileLength = [fileContents length];
    if (fileLength == 0) {
        fileContents = [NSString stringWithContentsOfFile:inputFile]; //if ascii doesnt work, have to use the deprecated (thankfully not obsolete!) method
    }
    fileLength = [fileContents length];
    if (fileLength == 0)
        return nil;
    
    NSScanner *theScanner;
    NSString *text = nil;
    NSDictionary *returnDict = nil;
    theScanner = [NSScanner scannerWithString:fileContents];
    while ([theScanner isAtEnd] == NO) {
        [theScanner scanUpToString:@"<?xml" intoString:NULL];
        [theScanner scanUpToString:@"</plist>" intoString:&text];
        text = [text stringByAppendingFormat:@"\n</plist>"];
        //NSLog(@"text: %@", [text dictionaryRepresentation]);
        NSDictionary *dict = [text dictionaryRepresentation];
        if (dict && [dict allKeys].count > 0) {
            if (![[dict allKeys] containsObject:@"CFBundleExecutable"] && ![[dict allKeys] containsObject:@"cdhashes"]){
                returnDict = dict;
                NSLog(@"got im?");
                break;
                //[dicts addObject:dict];
            }
        }
    }
    return returnDict;
}

- (NSString *)testGetEntso:(NSString *)inputFile {
    NSString *fileContents = [NSString stringWithContentsOfFile:inputFile encoding:NSASCIIStringEncoding error:nil];
    NSUInteger fileLength = [fileContents length];
    if (fileLength == 0)
        fileContents = [NSString stringWithContentsOfFile:inputFile]; //if ascii doesnt work, have to use the deprecated (thankfully not obsolete!) method
    
    fileLength = [fileContents length];
    if (fileLength == 0)
        return nil;
    
    NSUInteger startingLocation = [fileContents rangeOfString:@"<?xml"].location;
    
    //find NSRange of the end of the plist (there is "junk" cert data after our plist info as well
    NSRange endingRange = [fileContents rangeOfString:@"</plist>"];
    
    //adjust the location of endingRange to include </plist> into our newly trimmed string.
    NSUInteger endingLocation = endingRange.location + endingRange.length;
    
    //offset the ending location to trim out the "garbage" before <?xml
    NSUInteger endingLocationAdjusted = endingLocation - startingLocation;
    
    //create the final range of the string data from <?xml to </plist>
    
    NSRange plistRange = NSMakeRange(startingLocation, endingLocationAdjusted);
    
    //actually create our string!
    return [fileContents substringWithRange:plistRange];
}

- (void)processRootFolder:(NSString *)rootFolder {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSDictionary *rawDaemonDetails = [self rawDaemonDetailsForPath:rootFolder];
        NSString *outputFile = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop/daemons.plist"];
        [rawDaemonDetails writeToFile:outputFile atomically:true];
    });
}

- (void)doStuffWithFile:(NSString *)file {
    NSString *outputFolder = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop/HHT"];
    [[NSFileManager defaultManager] createDirectoryAtPath:outputFolder withIntermediateDirectories:true attributes:nil error:nil];
    NSLog(@"performing class dump on file: %@ to folder: %@", file, outputFolder);
    [classdump performClassDumpOnFile:file toFolder:outputFolder];
}

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
