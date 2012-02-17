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
//#define TAR_VERBOSE_LOG_MODE

// const definition
#define TAR_BLOCK_SIZE 512
#define TAR_TYPE_POSITION 156
#define TAR_NAME_POSITION 0
#define TAR_NAME_SIZE 100
#define TAR_SIZE_POSITION 124
#define TAR_SIZE_SIZE 12

#define TAR_MAX_BLOCK_LOAD_IN_MEMORY 100

// Error const
#define TAR_ERROR_DOMAIN @"com.lightuntar"
#define TAR_ERROR_CODE_BAD_BLOCK 1
#define TAR_ERROR_CODE_SOURCE_NOT_FOUND 2

#pragma mark - Private Methods
@interface NSFileManager(Tar_Private)
-(BOOL)createFilesAndDirectoriesAtPath:(NSString *)path withTarObject:(id)object size:(int)size error:(NSError **)error;

+ (char)typeForObject:(id)object atOffset:(int)offset;
+ (NSString*)nameForObject:(id)object atOffset:(int)offset;
+ (int)sizeForObject:(id)object atOffset:(int)offset;
- (void)writeFileDataForObject:(id)object inRange:(NSRange)range atPath:(NSString*)path;
+ (NSData*)dataForObject:(id)object inRange:(NSRange)range;
@end

#pragma mark - Implementation
@implementation NSFileManager (Tar)

- (BOOL)createFilesAndDirectoriesAtURL:(NSURL*)url withTarData:(NSData*)tarData error:(NSError**)error
{
    return[self createFilesAndDirectoriesAtPath:[url path] withTarData:tarData error:error];
}

- (BOOL)createFilesAndDirectoriesAtPath:(NSString*)path withTarData:(NSData*)tarData error:(NSError**)error
{
    return [self createFilesAndDirectoriesAtPath:path withTarObject:tarData size:[tarData length] error:error];
}

-(BOOL)createFilesAndDirectoriesAtPath:(NSString *)path withTarPath:(NSString *)tarPath error:(NSError **)error
{
    NSFileManager * filemanager = [NSFileManager defaultManager];
    if([filemanager fileExistsAtPath:tarPath]){
        NSDictionary * attributes = [filemanager attributesOfItemAtPath:tarPath error:nil];        
        int size = [[attributes objectForKey:NSFileSize] intValue];
        
        NSFileHandle* fileHandle = [NSFileHandle fileHandleForReadingAtPath:tarPath];
        BOOL result = [self createFilesAndDirectoriesAtPath:path withTarObject:fileHandle size:size error:error];
        [fileHandle closeFile];
        return result;
    }
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Source file not found" 
                                                         forKey:NSLocalizedDescriptionKey];
    if (error != NULL) *error = [NSError errorWithDomain:TAR_ERROR_DOMAIN code:TAR_ERROR_CODE_SOURCE_NOT_FOUND userInfo:userInfo];
    return NO;
}

-(BOOL)createFilesAndDirectoriesAtPath:(NSString *)path withTarObject:(id)object size:(int)size error:(NSError **)error
{
    [self createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil]; //Create path on filesystem
    
    long location = 0; // Position in the file
    while (location<size) {       
        long blockCount = 1; // 1 block for the header
        
        switch ([NSFileManager typeForObject:object atOffset:location]) {
            case '0': // It's a File
            {                
                NSString* name = [NSFileManager nameForObject:object atOffset:location];
#ifdef TAR_VERBOSE_LOG_MODE
                NSLog(@"UNTAR - file - %@",name);  
#endif
                NSString *filePath = [path stringByAppendingPathComponent:name]; // Create a full path from the name
                
                long size = [NSFileManager sizeForObject:object atOffset:location];
                
                if (size == 0){
#ifdef TAR_VERBOSE_LOG_MODE
                    NSLog(@"UNTAR - empty_file - %@", filePath);
#endif
                    [@"" writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:error];
                    break;
                }

                blockCount += (size-1)/TAR_BLOCK_SIZE+1; // size/TAR_BLOCK_SIZE rounded up
                
                [self writeFileDataForObject:object inRange:NSMakeRange(location+TAR_BLOCK_SIZE, size) atPath:filePath];                
                break;
            }
            case '5': // It's a directory
            {
                NSString* name = [NSFileManager nameForObject:object atOffset:location];
#ifdef TAR_VERBOSE_LOG_MODE
                NSLog(@"UNTAR - directory - %@",name); 
#endif
                NSString *directoryPath = [path stringByAppendingPathComponent:name]; // Create a full path from the name
                [self createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:nil]; //Write the directory on filesystem
                break;
            }
            case '\0': // It's a nul block
            {
#ifdef TAR_VERBOSE_LOG_MODE
                NSLog(@"UNTAR - empty block"); 
#endif
                break;
            }
            case '1':
            case '2':
            case '3':
            case '4':
            case '6':
            case '7':
            case 'x':
            case 'g': // It's not a file neither a directory
            {
#ifdef TAR_VERBOSE_LOG_MODE
                NSLog(@"UNTAR - unsupported block"); 
#endif
                long size = [NSFileManager sizeForObject:object atOffset:location];
                blockCount += ceil(size/TAR_BLOCK_SIZE);
                break;
            }          
            default: // It's not a tar type
            {
                NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Invalid block type found" 
                                                                     forKey:NSLocalizedDescriptionKey];
                if (error != NULL) *error = [NSError errorWithDomain:TAR_ERROR_DOMAIN code:TAR_ERROR_CODE_BAD_BLOCK userInfo:userInfo];
                return NO;
            }
        }
        
        location+=blockCount*TAR_BLOCK_SIZE;
    }
    return YES;
}

#pragma mark Private methods implementation

+ (char)typeForObject:(id)object atOffset:(int)offset
{
    char type;
    memcpy(&type,[self dataForObject:object inRange:NSMakeRange(offset+TAR_TYPE_POSITION, 1)].bytes, 1);
    return type;
}

+ (NSString*)nameForObject:(id)object atOffset:(int)offset
{
    char nameBytes[TAR_NAME_SIZE+1]; // TAR_NAME_SIZE+1 for nul char at end
    memset(&nameBytes, '\0', TAR_NAME_SIZE+1); // Fill byte array with nul char
    memcpy(&nameBytes,[self dataForObject:object inRange:NSMakeRange(offset+TAR_NAME_POSITION, TAR_NAME_SIZE)].bytes, TAR_NAME_SIZE);
    return [NSString stringWithCString:nameBytes encoding:NSASCIIStringEncoding];
}

+ (int)sizeForObject:(id)object atOffset:(int)offset
{
    char sizeBytes[TAR_SIZE_SIZE+1]; // TAR_SIZE_SIZE+1 for nul char at end
    memset(&sizeBytes, '\0', TAR_SIZE_SIZE+1); // Fill byte array with nul char
    memcpy(&sizeBytes,[self dataForObject:object inRange:NSMakeRange(offset+TAR_SIZE_POSITION, TAR_SIZE_SIZE)].bytes, TAR_SIZE_SIZE);
    return strtol(sizeBytes, NULL, 8); // Size is an octal number, convert to decimal
}

- (void)writeFileDataForObject:(id)object inRange:(NSRange)range atPath:(NSString*)path
{
    if([object isKindOfClass:[NSData class]]) {
        [self createFileAtPath:path contents:[object subdataWithRange:range] attributes:nil]; //Write the file on filesystem
    }
    else if([object isKindOfClass:[NSFileHandle class]]) {
        if([[NSData data] writeToFile:path atomically:NO]) {
            
            NSFileHandle *destinationFile = [NSFileHandle fileHandleForWritingAtPath:path];
            [object seekToFileOffset:range.location];
            
            int maxSize = TAR_MAX_BLOCK_LOAD_IN_MEMORY*TAR_BLOCK_SIZE;
            while(range.length > maxSize) {
                NSAutoreleasePool *poll = [[NSAutoreleasePool alloc] init];
                [destinationFile writeData:[object readDataOfLength:maxSize]];
                range = NSMakeRange(range.location+maxSize,range.length-maxSize);
                [poll release];
            }
            [destinationFile writeData:[object readDataOfLength:range.length]];
            [destinationFile closeFile];
        }
    }
}

+ (NSData*)dataForObject:(id)object inRange:(NSRange)range
{
    if([object isKindOfClass:[NSData class]]) {
        return [object subdataWithRange:range];
    }
    else if([object isKindOfClass:[NSFileHandle class]]) {
        [object seekToFileOffset:range.location];
        return [object readDataOfLength:range.length];
    }
    return nil;
}

@end