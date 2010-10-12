//
//  MainWindowController.h
//  Server
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import "TCPServer.h"

@interface MainWindowController : NSWindowController < TCPServerDelegate, NSStreamDelegate, NSWindowDelegate, MRDeviceDelegate > {
	
  @private
	MRNXTDevice *_device;
	TCPServer *_server;
	NSInputStream *_inputStream;
}

@property (nonatomic, assign) IBOutlet NSTextField *statusLabel;

- (id)initWithDevice:(IOBluetoothDevice *)device;

@end
