//
//  FMDatabaseIntegrityCheckTests.m
//  fmdb
//
//  Created by Mark Pustjens <pustjens@dds.nl> on 24/09/15.
//  (c) Angelbird Technologies GmbH
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

static NSString *const brokenDatabasePath = @"/tmp/tmp-broken.db";
static NSString *const populatedDatabasePath = @"/tmp/tmp-populated.db";

@interface FMDatabaseIntegrityCheckTests : FMDBTempDBTests

@end

@implementation FMDatabaseIntegrityCheckTests

+ (void)populateDatabase:(FMDatabase *)db
{
	[db executeUpdate:@"create table test (a text, b text, c integer, d double, e double)"];
	
	[db beginTransaction];
	int i = 0;
	while (i++ < 20) {
		[db executeUpdate:@"insert into test (a, b, c, d, e) values (?, ?, ?, ?, ?)" ,
		 @"hi'", // look!  I put in a ', and I'm not escaping it!
		 [NSString stringWithFormat:@"number %d", i],
		 [NSNumber numberWithInt:i],
		 [NSDate date],
		 [NSNumber numberWithFloat:2.2f]];
	}
	[db commit];
	
	// do it again, just because
	[db beginTransaction];
	i = 0;
	while (i++ < 20) {
		[db executeUpdate:@"insert into test (a, b, c, d, e) values (?, ?, ?, ?, ?)" ,
		 @"hi again'", // look!  I put in a ', and I'm not escaping it!
		 [NSString stringWithFormat:@"number %d", i],
		 [NSNumber numberWithInt:i],
		 [NSDate date],
		 [NSNumber numberWithFloat:2.2f]];
	}
	[db commit];
	
	[db executeUpdate:@"create table t3 (a somevalue)"];
	
	[db beginTransaction];
	for (int i=0; i < 20; i++) {
		[db executeUpdate:@"insert into t3 (a) values (?)", [NSNumber numberWithInt:i]];
	}
	[db commit];
}

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testIntegrityGoodDatabase
{
	NSString *log;
	
	/* 2 quick checks, one with, one without log parameter */
	XCTAssertTrue([self.db integrityCheck:YES log:nil], @"Should pass");
	XCTAssertTrue([self.db integrityCheck:YES log:&log], @"Should pass");
	XCTAssert([log isEqualToString:@"ok"], @"Should return \"ok\"");

	/* 2 full checks, one with, one without log parameter */
	XCTAssertTrue([self.db integrityCheck:NO log:nil], @"Should pass");
	XCTAssertTrue([self.db integrityCheck:NO log:&log], @"Should pass");
	XCTAssert([log isEqualToString:@"ok"], @"Should return \"ok\"");
}

- (void)testIntegrityBrokenDatabase
{
	NSFileManager *filemanager = [NSFileManager defaultManager];

	// delete old corrupted database
	[filemanager removeItemAtPath:brokenDatabasePath error:NULL];
	
	// copy a know-good database (could result in a corrupted database
	// when not using the sqlite backup feature)
	XCTAssertTrue([filemanager copyItemAtPath:populatedDatabasePath toPath:brokenDatabasePath error:NULL], @"Should pass");
	
	// remove 20% of the copied database
	NSFileHandle *fh = [NSFileHandle fileHandleForUpdatingAtPath:brokenDatabasePath];
	XCTAssert(fh != nil, @"Should pass");
	UInt64 size = [fh seekToEndOfFile];
	size = size * 0.8;
	[fh truncateFileAtOffset:size];
	[fh closeFile];
	
	
	// open the corrupted database
	FMDatabase *db = [FMDatabase databaseWithPath:brokenDatabasePath];
	XCTAssertTrue([db open]);
	
	NSString *log;
	
	/* 2 quick checks, one with, one without log parameter */
	XCTAssertFalse([db integrityCheck:YES log:nil], @"Should fail");
	XCTAssertFalse([db integrityCheck:YES log:&log], @"Should fail");
	XCTAssert(![log isEqualToString:@"ok"], @"Should NOT return \"ok\"");
	
	/* 2 full checks, one with, one without log parameter */
	XCTAssertFalse([db integrityCheck:NO log:nil], @"Should fail");
	XCTAssertFalse([db integrityCheck:NO log:&log], @"Should fail");
	XCTAssert(![log isEqualToString:@"ok"], @"Should NOT return \"ok\"");
	
	// close the corrupted db
	[db close];
}

@end
