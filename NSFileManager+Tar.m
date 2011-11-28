//
//  NSFileManager+Tar.m
//  Tar
//
//  Created by Mathieu Hausherr Octo Technology on 25/11/11.
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR(S) ``AS IS'' AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
// OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
// IN NO EVENT SHALL THE AUTHOR(S) BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
// NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
// THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "NSFileManager+Tar.h"

#pragma mark - Definitions

// Login mode
// Comment this line for production
#define TAR_VERBOSE_LOG_MODE

// const definition
#define TAR_BLOCK_SIZE 512
#define TAR_TYPE_POSITION 156
#define TAR_NAME_POSITION 0
#define TAR_NAME_SIZE 100
#define TAR_SIZE_POSITION 124
#define TAR_SIZE_SIZE 12


#pragma mark - Private Methods
@interface NSFileManager(Tar_Private)
+ (char)typeForData:(NSData*)data withOffset:(int)offset;
+ (NSString*)nameForData:(NSData*)data withOffset:(int)offset;
+ (int)sizeForData:(NSData*)data withOffset:(int)offset;
+ (NSData*)fileDataForData:(NSData*)data withLength:(int)length withOffset:(int)offset;
@end

#pragma mark - Implementation
@implementation NSFileManager (Tar)

- (void)createFilesAndDirectoriesAtURL:(NSURL*)url withTarData:(NSData*)tarData error:(NSError**)error
{
    [self createFilesAndDirectoriesAtPath:[url path] withTarData:tarData error:error];
}

- (void)createFilesAndDirectoriesAtPath:(NSString*)path withTarData:(NSData*)tarData error:(NSError**)pError
{
    long tarSize = [tarData length]; // size of file
    long location = 0; // Position in the file
    while (location<tarSize) {       
        long blockCount = 1; // 1 block for the header
        
        switch ([NSFileManager typeForData:tarData withOffset:location]) {
            case '0': // It's a File
            {                
                NSString* name = [NSFileManager nameForData:tarData withOffset:location];
#ifdef TAR_VERBOSE_LOG_MODE
                NSLog(@"UNTAR - file - %@",name);  
#endif
                NSString *filePath = [path stringByAppendingPathComponent:name]; // Create a full path from the name
                
                long size = [NSFileManager sizeForData:tarData withOffset:location];
                blockCount += (size-1)/TAR_BLOCK_SIZE+1; // size/TAR_BLOCK_SIZE rounded up
                
                NSData *fileData = [NSFileManager fileDataForData:tarData withLength:size withOffset:location];
                [self createFileAtPath:filePath contents:fileData attributes:nil]; //Write the file on filesystem
                
                break;
            }
            case '5': // It's a directory
            {
                NSString* name = [NSFileManager nameForData:tarData withOffset:location];
#ifdef TAR_VERBOSE_LOG_MODE
                NSLog(@"UNTAR - directory - %@",name); 
#endif
                NSString *directoryPath = [path stringByAppendingPathComponent:name]; // Create a full path from the name
                [self createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:pError]; //Write the directory on filesystem
                break;
            }
            default: // It's not a file neither a directory
#ifdef TAR_VERBOSE_LOG_MODE
                NSLog(@"UNTAR - empty block"); 
#endif
                break;
        }
        
        location+=blockCount*TAR_BLOCK_SIZE;
    }
}

#pragma mark Private methods implementation

+ (char)typeForData:(NSData*)data withOffset:(int)offset
{
    char type;
    [data getBytes:&type range:NSMakeRange(offset+TAR_TYPE_POSITION, 1)];
    return type;
}

+ (NSString*)nameForData:(NSData*)data withOffset:(int)offset
{
    char nameBytes[TAR_NAME_SIZE+1]; // TAR_NAME_SIZE+1 for nul char at end
    memset(&nameBytes, '\0', TAR_NAME_SIZE+1); // Fill byte array with nul char 
    [data getBytes:&nameBytes range:NSMakeRange(offset+TAR_NAME_POSITION, TAR_NAME_SIZE)];
    return [NSString stringWithCString:nameBytes encoding:NSASCIIStringEncoding];
}

+ (int)sizeForData:(NSData*)data withOffset:(int)offset
{
    char sizeBytes[TAR_SIZE_SIZE+1]; // TAR_SIZE_SIZE+1 for nul char at end
    memset(&sizeBytes, '\0', TAR_SIZE_SIZE+1); // Fill byte array with nul char
    [data getBytes:&sizeBytes range:NSMakeRange(offset+TAR_SIZE_POSITION, TAR_SIZE_SIZE)];
    return strtol(sizeBytes, NULL, 8); // Size is an octal number, convert to decimal
}

+ (NSData*)fileDataForData:(NSData*)data withLength:(int)length withOffset:(int)offset
{
    return [NSData dataWithBytes:data.bytes+offset+TAR_BLOCK_SIZE length:length];
}

@end