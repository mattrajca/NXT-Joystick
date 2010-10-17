//
//  JoystickViewController.m
//  Joystick
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import "JoystickViewController.h"

#import "Packet.h"

@interface JoystickViewController ()

- (void)showBrowser:(NSNumber *)animated; /* BOOL */
- (void)enteredBackground:(NSNotification *)not;
- (void)stopClient;
- (void)handleNetworkFail;
- (void)processMotion:(CMDeviceMotion *)motion;

@end


@implementation JoystickViewController

@synthesize statusLabel;

// BK: http://www.flickr.com/photos/torley/2587091353/

#define TURN_INTERVAL 5
#define POWER_INTERVAL 10
#define MAX_TURN 50
#define MAX_POWER_OFFSET 120
#define MAX_POWER 100

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super init];
	if (self) {
		_writeQueue = [[NSOperationQueue alloc] init];
		[_writeQueue setMaxConcurrentOperationCount:1];
		
		_motionManager = [[CMMotionManager alloc] init];
		_motionManager.deviceMotionUpdateInterval = 0.25f;
	}
	return self;
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	
	if (!_displayedOnce) {
		[self performSelector:@selector(showBrowser:)
				   withObject:[NSNumber numberWithBool:YES]
				   afterDelay:0.25f];
		
		_displayedOnce = YES;
	}
}

- (void)showBrowser:(NSNumber *)animated {
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:UIApplicationWillResignActiveNotification
												  object:[UIApplication sharedApplication]];
	
	BrowserViewController *vc = [[BrowserViewController alloc] init];
	vc.delegate = self;
	vc.serviceType = @"_nxtjoystick._tcp.";
	vc.domain = @"";
	
	UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
	[vc release];
	
	[self presentModalViewController:nav animated:[animated boolValue]];
	[nav release];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation == UIInterfaceOrientationLandscapeRight;
}

- (void)enteredBackground:(NSNotification *)not {
	if (_outputStream) {
		[self stopClient];
		[self showBrowser:nil];
	}
}

- (void)browserViewController:(BrowserViewController *)bvc
			didResolveService:(NSNetService *)service {
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(enteredBackground:)
												 name:UIApplicationWillResignActiveNotification
											   object:[UIApplication sharedApplication]];
	
	[service getInputStream:NULL outputStream:&_outputStream];
	
	[_outputStream retain];
	[_outputStream setDelegate:self];
	[_outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[_outputStream open];
}

- (void)stopClient {
	[_writeQueue cancelAllOperations];
	[_motionManager stopDeviceMotionUpdates];
	
	[_outputStream close];
	[_outputStream release];
	_outputStream = nil;
	
	[_refAttitude release];
	_refAttitude = nil;
	
	[_prevPacket release];
	_prevPacket = nil;
}

- (void)handleNetworkFail {
	[self stopClient];
	[self showBrowser:[NSNumber numberWithBool:YES]];
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
	if (eventCode == NSStreamEventOpenCompleted) {
		[_motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue]
								 withHandler:^(CMDeviceMotion *motion, NSError *error) {
									 
									 [self processMotion:motion];
									 
								 }];
	}
	else if (eventCode == NSStreamEventEndEncountered ||
			 eventCode == NSStreamEventErrorOccurred) {
		
		[self performSelectorOnMainThread:@selector(handleNetworkFail)
							   withObject:nil
							waitUntilDone:NO];
	}
}

static int mr_int_clamp (int v, int min, int max) {
	if (v < min)
		return min;
	else if (v > max)
		return max;
	
	return v;
}

- (void)processMotion:(CMDeviceMotion *)motion {
	if (!_refAttitude) {
		_refAttitude = [[motion attitude] retain];
	}
	
	[[motion attitude] multiplyByInverseOfAttitude:_refAttitude];
	
	Packet *packet = [[Packet alloc] init];
	
	double inside = motion.attitude.pitch * MAX_TURN / TURN_INTERVAL;
	
	if (inside > 0) {
		packet.turnRatio = mr_int_clamp(((int8_t) floor(inside)) * TURN_INTERVAL, -20, 20);
	}
	else if (inside < 0) {
		packet.turnRatio =  mr_int_clamp(((int8_t) ceil(inside)) * TURN_INTERVAL, -20, 20);
	}
	
	inside = (MAX_POWER_OFFSET - (-motion.attitude.roll) * MAX_POWER) / POWER_INTERVAL;
	packet.power =  mr_int_clamp(((int8_t) floor(inside)) * POWER_INTERVAL, 0, 100);
	
	if (_prevPacket) {
		if (packet.turnRatio == _prevPacket.turnRatio && packet.power == _prevPacket.power) {
			[packet release];
			return;
		}
	}
	
	_prevPacket = [packet retain];
	[packet release];
	
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:packet];
	
	[_writeQueue addOperationWithBlock:^{
		
		if (!_outputStream)
			return;
		
		if ([_outputStream write:[data bytes] maxLength:[data length]] < 0) {
			[self performSelectorOnMainThread:@selector(handleNetworkFail)
								   withObject:nil
								waitUntilDone:NO];
		}
		
	}];
}

- (IBAction)stop:(id)sender {
	[self stopClient];
	[self showBrowser:[NSNumber numberWithBool:YES]];
}

- (void)dealloc {
	[_motionManager release];
	[_writeQueue release];
	[_outputStream release];
	[_refAttitude release];
	
	self.statusLabel = nil;
	
    [super dealloc];
}

@end
