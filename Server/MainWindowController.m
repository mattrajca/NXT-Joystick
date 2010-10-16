//
//  MainWindowController.m
//  Server
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import "MainWindowController.h"

#import "Packet.h"

@interface MainWindowController ()

- (void)setupDevice:(IOBluetoothDevice *)device;
- (void)startServer;
- (void)forwardPacket:(Packet *)packet;

@end


@implementation MainWindowController

@synthesize statusLabel;

#define BUFF_SIZE 4096

- (id)initWithDevice:(IOBluetoothDevice *)device {
	self = [super initWithWindowNibName:@"MainWindow"];
	if (self) {
		[self setupDevice:device];
	}
	return self;
}

- (void)windowDidAppear {
	[[self window] setDelegate:self];
}

- (void)showWindow:(id)sender {
	[super showWindow:sender];
	
	[self windowDidAppear];
}

- (void)windowWillClose:(NSNotification *)notification {
	[_device close];
	
	if (_server) {
		[_server stop];
	}
	
	if (_inputStream) {
		[_inputStream close];
		[_inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	}
}

- (void)setupDevice:(IOBluetoothDevice *)device {
	MRBluetoothDeviceTransport *t = [[MRBluetoothDeviceTransport alloc] initWithBluetoothDevice:device];
	
	_device = [[MRNXTDevice alloc] initWithTransport:t];
	[_device setDelegate:self];
	
	NSError *error = nil;
	
	if (![_device open:&error]) {
		[self close];
		[NSApp presentError:error];
	}
}

- (void)deviceDidClose:(MRDevice *)aDevice {
	[self close];
}

- (void)deviceDidOpen:(MRDevice *)aDevice {
	[self.statusLabel setStringValue:@"Starting server..."];
	
	[self startServer];
}

- (void)device:(MRDevice *)aDevice didFailToOpen:(NSError *)error {
	[self close];
	[NSApp presentError:error];
}

- (void)startServer {
	_server = [[TCPServer alloc] init];
	_server.delegate = self;
	
	NSError *error = nil;
	
	if (![_server start:&error]) {
		[self close];
		[NSApp presentError:error];
		
		return;
	}
	
	[_server enableBonjourWithDomain:@""
				 applicationProtocol:[TCPServer bonjourTypeFromIdentifier:@"nxtjoystick"]
								name:@""];
	
	[self.statusLabel setStringValue:@"Waiting for iOS devices..."];
}

- (void)stopServer {
	_server = nil;
}

- (void)server:(TCPServer *)server didAcceptConnectionWithInputStream:(NSInputStream *)is
  outputStream:(NSOutputStream *)os {
	
	[_server stop];
	
	[self.statusLabel setStringValue:@"Accepting incoming connection..."];
	
	_inputStream = is;
	
	[_inputStream setDelegate:self];
	[_inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[_inputStream open];
	
	[self performSelector:@selector(stopServer) withObject:nil afterDelay:0.0f];
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
	if (eventCode == NSStreamEventOpenCompleted) {
		[self.statusLabel setStringValue:@"Successfully opened connection!"];
	}
	else if (eventCode == NSStreamEventHasBytesAvailable) {
		uint8_t buff[BUFF_SIZE];
		size_t read = [_inputStream read:buff maxLength:BUFF_SIZE];
		
		NSData *data = [NSData dataWithBytes:buff length:read];
		Packet *packet = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		
		[self performSelector:@selector(forwardPacket:) withObject:packet afterDelay:0.0f];
	}
}

- (void)driveMotor:(NXTOutputPort)port power:(int8_t)power turnRatio:(int8_t)turnRatio {
	MRNXTSetOutputStateCommand *cmd = [[MRNXTSetOutputStateCommand alloc] init];
	cmd.outputMode = NXTOutputModeMotorOn | NXTOutputModeRegulated;
	cmd.port = port;
	cmd.power = power;
	cmd.regulationMode = NXTRegulationModeMotorSync;
	cmd.runState = NXTRunStateRunning;
	cmd.tachoLimit = 0;
	cmd.turnRatio = turnRatio;
	
	[_device enqueueCommand:cmd responseBlock:NULL];
}

- (void)forwardPacket:(Packet *)packet {
	[self driveMotor:NXTOutputPortB power:packet.power turnRatio:packet.turnRatio];
	[self driveMotor:NXTOutputPortC power:packet.power turnRatio:packet.turnRatio];
}

@end
