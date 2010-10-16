/*
 File: TCPServer.m
 Abstract: A TCP server that listens on an arbitrary port.
 Version: 1.7mr
 
 Disclaimer: IMPORTANT:	 This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.	 If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.	Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2009 Apple Inc. All Rights Reserved.
 
 */

#import "TCPServer.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

NSString *const TCPServerErrorDomain = @"TCPServerErrorDomain";

@implementation TCPServer

@synthesize delegate;

+ (NSString *)bonjourTypeFromIdentifier:(NSString *)identifier {
	NSParameterAssert(identifier != nil);
	
	if (![identifier length])
		return nil;
	
	return [NSString stringWithFormat:@"_%@._tcp.", identifier];
}

- (void)handleNewConnectionFromAddress:(NSData *)addr
						   inputStream:(NSInputStream *)is
						  outputStream:(NSOutputStream *)os { 
	
	if ([self.delegate respondsToSelector:@selector(server:didAcceptConnectionWithInputStream:outputStream:)]) {
		[self.delegate server:self didAcceptConnectionWithInputStream:is outputStream:os];
	}
}

static void TCPServerAcceptCallBack (CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
	
	TCPServer *self = (TCPServer *) info;
	
	if (type == kCFSocketAcceptCallBack) { 
		CFSocketNativeHandle nativeSocketHandle = *(CFSocketNativeHandle *) data;
		
		uint8_t name[SOCK_MAXADDRLEN];
		socklen_t namelen = sizeof(name);
		
		NSData *peer = nil;
		
		if (!getpeername(nativeSocketHandle, (struct sockaddr *) name, &namelen)) {
			peer = [NSData dataWithBytes:name length:namelen];
		}
		
		CFReadStreamRef readStream = NULL;
		CFWriteStreamRef writeStream = NULL;
		
		CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeSocketHandle, &readStream, &writeStream);
		
		if (readStream && writeStream) {
			CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
			CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
			
			[self handleNewConnectionFromAddress:peer inputStream:(NSInputStream *) readStream
									outputStream:(NSOutputStream *) writeStream];
		}
		else {
			close(nativeSocketHandle);
		}
		
		if (readStream)
			CFRelease(readStream);
		
		if (writeStream)
			CFRelease(writeStream);
	}
}

- (BOOL)start:(NSError **)error {
	CFSocketContext ctx = { 0, self, NULL, NULL, NULL };
	
	_socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, (CFSocketCallBack) &TCPServerAcceptCallBack, &ctx);
	
	if (!_socket) {
		if (error)
			*error = [[NSError alloc] initWithDomain:TCPServerErrorDomain
												code:kTCPServerNoSocketsAvailable
											userInfo:nil];
		
		return NO;
	}
	
	int yes = 1;
	setsockopt(CFSocketGetNative(_socket), SOL_SOCKET, SO_REUSEADDR, (void *) &yes, sizeof(yes));
	
	struct sockaddr_in addr4;
	memset(&addr4, 0, sizeof(addr4));
	
	addr4.sin_len = sizeof(addr4);
	addr4.sin_family = AF_INET;
	addr4.sin_port = 0;
	addr4.sin_addr.s_addr = htonl(INADDR_ANY);
	
	NSData *address4 = [NSData dataWithBytes:&addr4 length:sizeof(addr4)];
	
	if (CFSocketSetAddress(_socket, (CFDataRef) address4) != kCFSocketSuccess) {
		if (error)
			*error = [[NSError alloc] initWithDomain:TCPServerErrorDomain
												code:kTCPServerCouldNotBindToIPv4Address
											userInfo:nil];
		
		if (_socket) {
			CFRelease(_socket);
			_socket = NULL;
		}
		
		return NO;
	}
	
	NSData *addr = [NSMakeCollectable(CFSocketCopyAddress(_socket)) autorelease];
	memcpy(&addr4, [addr bytes], [addr length]);
	
	_port = ntohs(addr4.sin_port);
	
	CFRunLoopRef cfrl = CFRunLoopGetCurrent();
	CFRunLoopSourceRef source4 = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socket, 0);
	CFRunLoopAddSource(cfrl, source4, kCFRunLoopCommonModes);
	CFRelease(source4);
	
	return YES;
}

- (BOOL)stop {
	[self disableBonjour];
	
	if (_socket) {
		CFSocketInvalidate(_socket);
		
		CFRelease(_socket);
		_socket = NULL;
	}
	
	return YES;
}

- (BOOL)enableBonjourWithDomain:(NSString *)domain
			applicationProtocol:(NSString *)protocol
						   name:(NSString *)name {
	
	if (![domain length])
		domain = @"";
	
	if (![name length])
		name = @"";
	
	if (![protocol length] || !_socket)
		return NO;
	
	_netService = [[NSNetService alloc] initWithDomain:domain type:protocol name:name port:_port];
	
	if (!_netService)
		return NO;
	
	[_netService setDelegate:self];
	[_netService publish];
	
	return YES;
}

- (void)netServiceDidPublish:(NSNetService *)sender {
	if ([self.delegate respondsToSelector:@selector(serverDidEnableBonjour:withName:)]) {
		[self.delegate serverDidEnableBonjour:self withName:sender.name];
	}
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict {
	if ([self.delegate respondsToSelector:@selector(server:didNotEnableBonjour:)]) {
		[self.delegate server:self didNotEnableBonjour:errorDict];
	}
}

- (void)disableBonjour {
	if (_netService) {
		[_netService stop];
		
		[_netService release];
		_netService = nil;
	}
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@ = 0x%08X | port %d | netService = %@>",
			[self class], (long) self, _port, _netService];
}

- (void)dealloc {
	[self stop];
	[super dealloc];
}

@end
