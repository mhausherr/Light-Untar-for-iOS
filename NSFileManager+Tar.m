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
#define TAR_BLOCK_SIZE                  512
#define TAR_TYPE_POSITION               156
#define TAR_NAME_POSITION               0
#define TAR_NAME_SIZE                   100
#define TAR_SIZE_POSITION               124
#define TAR_SIZE_SIZE                   12
#define TAR_MAX_BLOCK_LOAD_IN_MEMORY    100

// Error const
#define TAR_ERROR_DOMAIN                @"com.lightuntar"
#define TAR_ERROR_CODE_BAD_BLOCK        1
#define TAR_ERROR_CODE_SOURCE_NOT_FOUND 2

#pragma mark - Private Methods
@interface NSFileManager (Tar_Private)
- (BOOL)createFilesAndDirectoriesAtPath:(NSString *)path withTarObject:(id)object size:(unsigned long long)size error:(NSError **)error;

+ (char)typeForObject:(id)object atOffset:(unsigned long long)offset;
+ (NSString *)nameForObject:(id)object atOffset:(unsigned long long)offset;
+ (unsigned long long)sizeForObject:(id)object atOffset:(unsigned long long)offset;
- (void)writeFileDataForObject:(id)object inRange:(NSRange)range atPath:(NSString *)path;
- (void)writeFileDataForObject:(id)object atLocation:(unsigned long long)location withLength:(unsigned long long)length atPath:(NSString *)path;
+ (NSData *)dataForObject:(id)object inRange:(NSRange)range orLocation:(unsigned long long)location andLength:(unsigned long long)length;
@end

#pragma mark - Implementation
@implementation NSFileManager (Tar)

- (BOOL)createFilesAndDirectoriesAtURL:(NSURL *)url withTarData:(NSData *)tarData error:(NSError **)error
{
    return [self createFilesAndDirectoriesAtPath:[url path] withTarData:tarData error:error];
}

- (BOOL)createFilesAndDirectoriesAtPath:(NSString *)path withTarData:(NSData *)tarData error:(NSError **)error
{
    return [self createFilesAndDirectoriesAtPath:path withTarObject:tarData size:[tarData length] error:error];
}

- (BOOL)createFilesAndDirectoriesAtPath:(NSString *)path withTarPath:(NSString *)tarPath error:(NSError **)error
{
    NSFileManager *filemanager = [NSFileManager defaultManager];
    
    if ([filemanager fileExistsAtPath:tarPath]) {
        NSDictionary *attributes = [filemanager attributesOfItemAtPath:tarPath error:nil];
        unsigned long long size = [[attributes objectForKey:NSFileSize] longLongValue];  //NSFileSize returns an NSNumber long long
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:tarPath];
        BOOL result = [self createFilesAndDirectoriesAtPath:path withTarObject:fileHandle size:size error:error];
        [fileHandle closeFile];
        return result;
    }
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Source file not found"
                                                         forKey:NSLocalizedDescriptionKey];
    
    if (error != NULL) *error = [NSError errorWithDomain:TAR_ERROR_DOMAIN code:TAR_ERROR_CODE_SOURCE_NOT_FOUND userInfo:userInfo];
    
    return NO;
}

- (BOOL)createFilesAndDirectoriesAtPath:(NSString *)path
                          withTarObject:(id)object
                                   size:(unsigned long long)size
                               progress:(NSProgress*)progress
                                  error:(NSError **)error
{
    NSFileManager *filemanager = [NSFileManager defaultManager];
    
     //Create path on filesystem
    [filemanager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    unsigned long long location = 0; // Position in the file
    while (location < size) {
        progress.completedUnitCount = [self completionUnitCountForBytes:location];
        unsigned long long blockCount = 1; // 1 block for the header
        switch ([NVHTarFile typeForObject:object atOffset:location]) {
            case '0':   // It's a File,
            case '\0':  // It's also a File, needed for backward compatibility
            {
                @autoreleasepool {
                    NSString *name = [NVHTarFile nameForObject:object atOffset:location];
#ifdef TAR_VERBOSE_LOG_MODE
                    NSLog(@"UNTAR - file - %@", name);
#endif
                    NSString *filePath = [path stringByAppendingPathComponent:name]; // Create a full path from the name
                    
                    unsigned long long objectSize = [NVHTarFile sizeForObject:object atOffset:location];
                    
                    if (objectSize == 0 && name.length) {
#ifdef TAR_VERBOSE_LOG_MODE
                        NSLog(@"UNTAR - empty_file - %@", filePath);
#endif
                        NSError *writeError;
                        BOOL copied = [@"" writeToFile:filePath
                                            atomically:YES
                                              encoding:NSUTF8StringEncoding
                                                 error:&writeError];
                        if (!copied) {
#ifdef TAR_VERBOSE_LOG_MODE
                            NSLog(@"UNTAR - error during creating a directrory for a file - %@", writeError);
#endif
                        }
                        break;
                    }
                    
                    blockCount += (objectSize - 1) / TAR_BLOCK_SIZE + 1; // size/TAR_BLOCK_SIZE rounded up
                    
                    // The name field is the file name of the file,
                    // with directory names (if any) preceding the file name, separated by slashes.
                    if ([name lastPathComponent].length != name.length) {
                        NSString *directoryPath = [[path stringByAppendingPathComponent:name]
                                                   stringByDeletingLastPathComponent];
                        NSError *createError;
                        BOOL created = [filemanager createDirectoryAtPath:directoryPath
                                              withIntermediateDirectories:YES
                                                               attributes:nil
                                                                    error:&createError];
                        if (!created) {
#ifdef TAR_VERBOSE_LOG_MODE
                            NSLog(@"UNTAR - error during writing empty_file - %@", createError);
#endif
                        }
                    }
                    
                    [self writeFileDataForObject:object
                                      atLocation:(location + TAR_BLOCK_SIZE)
                                      withLength:objectSize
                                          atPath:filePath];
                }
                break;
            }
                
            case '5': // It's a directory
            {
                @autoreleasepool {
                    NSString *name = [NVHTarFile nameForObject:object atOffset:location];
#ifdef TAR_VERBOSE_LOG_MODE
                    NSLog(@"UNTAR - directory - %@", name);
#endif
                    // Create a full path from the name
                    NSString *directoryPath = [path stringByAppendingPathComponent:name];
                    NSError *createError;
                    BOOL created = [filemanager createDirectoryAtPath:directoryPath
                                          withIntermediateDirectories:YES
                                                           attributes:nil
                                                                error:&createError]; //Write the directory on filesystem
                    if (!created) {
#ifdef TAR_VERBOSE_LOG_MODE
                        NSLog(@"UNTAR - error during creating a directrory - %@", createError);
#endif
                    }
                }
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
                @autoreleasepool {
                    unsigned long long objectSize = [NVHTarFile sizeForObject:object atOffset:location];
                    blockCount += ceil(objectSize / TAR_BLOCK_SIZE);
                }
                break;
            }
                
            default: // It's not a tar type
            {
                NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Invalid block type found"
                                                                     forKey:NSLocalizedDescriptionKey];
                
                if (error != NULL) *error = [NSError errorWithDomain:TAR_ERROR_DOMAIN
                                                                code:TAR_ERROR_CODE_BAD_BLOCK
                                                            userInfo:userInfo];
                
                return NO;
            }
        }
        
        location += blockCount * TAR_BLOCK_SIZE;
    }
    progress.completedUnitCount = progress.totalUnitCount;
    return YES;
}

#pragma mark Private methods implementation

+ (char)typeForObject:(id)object atOffset:(unsigned long long)offset
{
    char type;
    
    memcpy(&type, [self dataForObject:object inRange:NSMakeRange(offset + TAR_TYPE_POSITION, 1) orLocation:offset + TAR_TYPE_POSITION andLength:1].bytes, 1);
    return type;
}

+ (NSString *)nameForObject:(id)object atOffset:(unsigned long long)offset
{
    char nameBytes[TAR_NAME_SIZE + 1]; // TAR_NAME_SIZE+1 for nul char at end
    
    memset(&nameBytes, '\0', TAR_NAME_SIZE + 1); // Fill byte array with nul char
    memcpy(&nameBytes, [self dataForObject:object inRange:NSMakeRange(offset + TAR_NAME_POSITION, TAR_NAME_SIZE) orLocation:offset + TAR_NAME_POSITION andLength:TAR_NAME_SIZE].bytes, TAR_NAME_SIZE);
    return [NSString stringWithCString:nameBytes encoding:NSASCIIStringEncoding];
}

+ (unsigned long long)sizeForObject:(id)object atOffset:(unsigned long long)offset
{
    char sizeBytes[TAR_SIZE_SIZE + 1]; // TAR_SIZE_SIZE+1 for nul char at end
    
    memset(&sizeBytes, '\0', TAR_SIZE_SIZE + 1); // Fill byte array with nul char
    memcpy(&sizeBytes, [self dataForObject:object inRange:NSMakeRange(offset + TAR_SIZE_POSITION, TAR_SIZE_SIZE) orLocation:offset + TAR_SIZE_POSITION andLength:TAR_SIZE_SIZE].bytes, TAR_SIZE_SIZE);
    return strtol(sizeBytes, NULL, 8); // Size is an octal number, convert to decimal
}

- (void)writeFileDataForObject:(id)object atLocation:(unsigned long long)location withLength:(unsigned long long)length atPath:(NSString *)path
{
    BOOL created = NO;
    if ([object isKindOfClass:[NSData class]]) {
        NSData *contents = [object subdataWithRange:NSMakeRange((NSUInteger)location, (NSUInteger)length)];
        created = [[NSFileManager defaultManager] createFileAtPath:path
                                                          contents:contents
                                                        attributes:nil]; //Write the file on filesystem
    } else if ([object isKindOfClass:[NSFileHandle class]]) {
        created = [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        if (created) {
            NSFileHandle *destinationFile = [NSFileHandle fileHandleForWritingAtPath:path];
            [object seekToFileOffset:location];
            
            unsigned long long maxSize = TAR_MAX_BLOCK_LOAD_IN_MEMORY * TAR_BLOCK_SIZE;
            
            while (length > maxSize) {
                @autoreleasepool {
                    [destinationFile writeData:[object readDataOfLength:(NSUInteger)maxSize]];
                    location += maxSize;
                    length -= maxSize;
                }
            }
            [destinationFile writeData:[object readDataOfLength:(NSUInteger)length]];
            [destinationFile closeFile];
        }
    }
    
    if (!created) {
#ifdef TAR_VERBOSE_LOG_MODE
        NSLog(@"UNTAR - can't create file");
#endif
    }
}

+ (NSData *)dataForObject:(id)object inRange:(NSRange)range orLocation:(unsigned long long)location andLength:(unsigned long long)length
{
    if ([object isKindOfClass:[NSData class]]) {
        return [object subdataWithRange:range];
    } else if ([object isKindOfClass:[NSFileHandle class]]) {
        [object seekToFileOffset:location];
        return [object readDataOfLength:length];
    }
    
    return nil;
}

@end