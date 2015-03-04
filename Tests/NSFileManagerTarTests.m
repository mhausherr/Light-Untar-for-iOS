//
//  NSFileManagerTarTests.m
//  Light-Untar
//
//  Created by Stéphane Prohaszka Octo Technology on 04/03/2015.
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
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import "NSFileManager+Tar.h"

#define HC_SHORTHAND
#import <OCHamcrest/OCHamcrest.h>

@interface NSFileManagerTarTests : XCTestCase

@property (nonatomic, strong) NSString *extractDir;

@end

@implementation NSFileManagerTarTests

- (void)setUp {
    [super setUp];
    
    self.extractDir = [NSString stringWithFormat:@"%@/extract/", [[NSBundle bundleForClass:[self class]] resourcePath]];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:self.extractDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
}

- (void)tearDown {
    [[NSFileManager defaultManager] removeItemAtPath:self.extractDir error:nil];
    
    [super tearDown];
}

- (void)testSimpleExtract {
    //GIVEN
    NSString *archivePath = [NSString stringWithFormat:@"%@/simple.tar",
                             [[NSBundle bundleForClass:[self class]] resourcePath]];
    
    //WHEN
    NSError *error;
    BOOL isExtracted = [[NSFileManager defaultManager] createFilesAndDirectoriesAtPath:self.extractDir
                                                                           withTarPath:archivePath
                                                                                 error:&error
                                                                              progress:nil];
    
    //THEN
    XCTAssertTrue(isExtracted, @"Error");
    assertThat(error, nilValue());
}

- (void)testAverageSizeFile {
    //GIVEN
    NSString *archivePath = [NSString stringWithFormat:@"%@/average.tar",
                             [[NSBundle bundleForClass:[self class]] resourcePath]];
    
    //WHEN
    NSError *error;
    BOOL isExtracted = [[NSFileManager defaultManager] createFilesAndDirectoriesAtPath:self.extractDir
                                                                           withTarPath:archivePath
                                                                                 error:&error
                                                                              progress:nil];
    
    //THEN
    XCTAssertTrue(isExtracted, @"Error");
    assertThat(error, nilValue());
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.extractDir error:nil];
    assertThat(files, notNilValue());
    assertThat(files, isNot(isEmpty()));
}

- (void)testBigSizeFile {
    //GIVEN
    NSString *archivePath = [NSString stringWithFormat:@"%@/big.tar",
                             [[NSBundle bundleForClass:[self class]] resourcePath]];
    
    //WHEN
    NSError *error;
    BOOL isExtracted = [[NSFileManager defaultManager] createFilesAndDirectoriesAtPath:self.extractDir
                                                                           withTarPath:archivePath
                                                                                 error:&error
                                                                              progress:nil];
    
    //THEN
    XCTAssertTrue(isExtracted, @"Error");
    assertThat(error, nilValue());
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.extractDir error:nil];
    assertThat(files, notNilValue());
    assertThat(files, isNot(isEmpty()));
}

- (void)testNotExistingFile {
    //GIVEN
    NSString *archivePath = [NSString stringWithFormat:@"%@/unknown.tar",
                             [[NSBundle bundleForClass:[self class]] resourcePath]];
    
    //WHEN
    NSError *error;
    BOOL isExtracted = [[NSFileManager defaultManager] createFilesAndDirectoriesAtPath:self.extractDir
                                                                           withTarPath:archivePath
                                                                                 error:&error
                                                                              progress:nil];
    
    //THEN
    XCTAssertFalse(isExtracted, @"Error");
    assertThat(error, notNilValue());
    assertThat(error.domain, equalTo(NSFileManagerLightUntarErrorDomain));
    assertThatLong(error.code, equalToLong(NSFileNoSuchFileError));
}

- (void)testCorruptedFile {
    //GIVEN
    NSString *archivePath = [NSString stringWithFormat:@"%@/corrupt.tar",
                             [[NSBundle bundleForClass:[self class]] resourcePath]];
    
    //WHEN
    NSError *error;
    BOOL isExtracted = [[NSFileManager defaultManager] createFilesAndDirectoriesAtPath:self.extractDir
                                                                           withTarPath:archivePath
                                                                                 error:&error
                                                                              progress:nil];

    //THEN
    XCTAssertFalse(isExtracted, @"Error");
    assertThat(error, notNilValue());
    assertThat(error.domain, equalTo(NSFileManagerLightUntarErrorDomain));
    assertThatLong(error.code, equalToLong(NSFileReadCorruptFileError));
}

@end
