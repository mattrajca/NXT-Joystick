//
//  Packet.h
//  Server
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

@interface Packet : NSObject < NSCoding > {

}

@property (nonatomic, assign) int8_t power;
@property (nonatomic, assign) int8_t turnRatio;

@end
