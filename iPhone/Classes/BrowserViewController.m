//
//  BrowserViewController.m
//  Joystick
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import "BrowserViewController.h"

@interface NSNetService (BrowserViewControllerAdditions)

- (NSComparisonResult)localizedCaseInsensitiveCompareByName:(NSNetService *)aService;

@end

@implementation NSNetService (BrowserViewControllerAdditions)

- (NSComparisonResult)localizedCaseInsensitiveCompareByName:(NSNetService *)aService {
	return [[self name] localizedCaseInsensitiveCompare:[aService name]];
}

@end

@interface BrowserViewController ()

- (void)stopBrowser;
- (void)startBrowser;

- (void)enteredBackground:(NSNotification *)not;
- (void)leftBackground:(NSNotification *)not;

@end


@implementation BrowserViewController

@synthesize delegate, serviceType, domain;

- (id)init {
	self = [super initWithStyle:UITableViewStylePlain];
	if (self) {
		self.title = NSLocalizedString(@"Computers", nil);
		_services = [[NSMutableArray alloc] init];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(enteredBackground:)
													 name:UIApplicationWillResignActiveNotification
												   object:[UIApplication sharedApplication]];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(leftBackground:)
													 name:UIApplicationWillEnterForegroundNotification
												   object:[UIApplication sharedApplication]];
	}
	return self;
}

- (void)stopBrowser {
	[_browser stop];
	[_services removeAllObjects];
	
	[self.tableView reloadData];
}

- (void)startBrowser {
	[self stopBrowser];
	
	if (!_browser) {
		_browser = [[NSNetServiceBrowser alloc] init];
		_browser.delegate = self;
	}
	
	[_browser searchForServicesOfType:self.serviceType inDomain:self.domain];
}

- (void)enteredBackground:(NSNotification *)not {
	[self stopBrowser];
}

- (void)leftBackground:(NSNotification *)not {
	[self startBrowser];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[self startBrowser];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_services count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *CellIdentifier = @"Cell";
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	
	if (!cell) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									   reuseIdentifier:CellIdentifier] autorelease];
	}
	
	NSNetService *service = [_services objectAtIndex:indexPath.row];
	cell.textLabel.text = [service name];
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSNetService *service = [_services objectAtIndex:indexPath.row];
	[service setDelegate:self];
	[service resolveWithTimeout:10.0f];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation == UIInterfaceOrientationLandscapeRight;
}

- (void)sortAndUpdateUI {
	[_services sortUsingSelector:@selector(localizedCaseInsensitiveCompareByName:)];
	[self.tableView reloadData];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
		 didRemoveService:(NSNetService *)service moreComing:(BOOL)moreComing {
	
	[_services removeObject:service];
	
	if (!moreComing) {
		[self sortAndUpdateUI];
	}
}	

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
		   didFindService:(NSNetService *)service moreComing:(BOOL)moreComing {
	
	[_services addObject:service];
	
	if (!moreComing) {
		[self sortAndUpdateUI];
	}
}	

- (void)netServiceDidResolveAddress:(NSNetService *)service {
	[self dismissModalViewControllerAnimated:YES];
	
	if ([self.delegate respondsToSelector:@selector(browserViewController:didResolveService:)]) {
		[self.delegate browserViewController:self
						   didResolveService:[[service retain] autorelease]];
	}
}

- (void)dealloc {
	[_browser stop];
	
	[_browser release];
	[_services release];
	
	[super dealloc];
}

@end
