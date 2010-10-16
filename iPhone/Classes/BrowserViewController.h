//
//  BrowserViewController.h
//  Joystick
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

@class BrowserViewController;

@protocol BrowserViewControllerDelegate < NSObject >

- (void)browserViewController:(BrowserViewController *)bvc didResolveService:(NSNetService *)service;

@end


@interface BrowserViewController : UITableViewController < NSNetServiceBrowserDelegate, NSNetServiceDelegate > {
  @private
	NSMutableArray *_services;
	NSNetServiceBrowser *_browser;
}

@property (nonatomic, assign) id < BrowserViewControllerDelegate > delegate;

@property (nonatomic, copy) NSString *serviceType;
@property (nonatomic, copy) NSString *domain;

@end
