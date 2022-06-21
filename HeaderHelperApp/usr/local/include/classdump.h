//
//  classdump.h
//  classdump
//
//  Created by Kevin Bradley on 6/21/22.
//

#import <Foundation/Foundation.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <getopt.h>
#include <stdlib.h>
#include <mach-o/arch.h>

#import "NSString-CDExtensions.h"

#import "CDClassDump.h"
#import "CDFindMethodVisitor.h"
#import "CDClassDumpVisitor.h"
#import "CDMultiFileVisitor.h"
#import "CDFile.h"
#import "CDMachOFile.h"
#import "CDFatFile.h"
#import "CDFatArch.h"
#import "CDSearchPathState.h"

@interface classdump : NSObject
+ (NSInteger)performClassDumpOnFile:(NSString *)file toFolder:(NSString *)outputPath;
@end
