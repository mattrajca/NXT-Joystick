//
//  Packet.m
//  Server
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import "Packet.h"

@implementation Packet

@synthesize power, turnRatio;

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeInteger:self.power forKey:@"power"];
	[aCoder encodeInteger:self.turnRatio forKey:@"turnRatio"];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super init];
	if (self) {
		self.power = [aDecoder decodeIntegerForKey:@"power"];
		self.turnRatio = [aDecoder decodeIntegerForKey:@"turnRatio"];
	}
	return self;
}

@end
