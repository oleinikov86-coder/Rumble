#import "RMRootViewController.h"
#import <NetworkExtension/NetworkExtension.h>

@implementation RMRootViewController
+ (NSArray<NSString *> *)shellSplit:(NSString *)string {
	NSMutableArray<NSString *> * tokens = [NSMutableArray<NSString *> array];
	BOOL escaping = NO;
	char quoteChar = ' ';
	BOOL quoting = false;
	NSInteger lastCloseQuoteIndex = NSIntegerMin;
	NSMutableString * current = [[NSMutableString alloc] init];
	unichar * chars = malloc(sizeof(unichar) * (string.length + 1));
	[string getCharacters:chars range:NSMakeRange(0, string.length)];
	chars[string.length] = L'\0';
	NSLog(@"shellSplit: %@", string);

	for (NSUInteger i = 0; i < string.length; ++i)
	{
		unichar c = chars[i];
		if (escaping)
		{
			[current appendString:[NSString stringWithCharacters:&c length:1]];
			escaping = NO;
		}
		else if (c == L'\\' && (!quoting || quoteChar != L'\''))
		{
			escaping = YES;
		}
		else if (quoting && c == quoteChar)
		{
			quoting = NO;
			lastCloseQuoteIndex = i;
		}
		else if (!quoting && (c == L'\'' || c == L'"'))
		{
			quoting = YES;
			quoteChar = c;
		}
		else if (!quoting && [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:c])
		{
			if (current.length != 0 || lastCloseQuoteIndex == i - 1)
			{
				[tokens addObject:current];
				current = [[NSMutableString alloc] init];
			}
		}
		else
		{
			[current appendString:[NSString stringWithCharacters:&c length:1]];
		}
	}
	free(chars);
	if (current.length != 0 || lastCloseQuoteIndex == string.length - 1)
	{
		[tokens addObject:current];
	}
	NSLog(@"shellSplit result: %@", tokens);
	return tokens;
}

- (void)showDebugAlert:(NSString *)title message:(NSString *)msg {
	dispatch_async(dispatch_get_main_queue(), ^{
		UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
		[a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
		UIViewController *r = [UIApplication sharedApplication].keyWindow.rootViewController;
		while (r.presentedViewController) r = r.presentedViewController;
		[r presentViewController:a animated:YES completion:nil];
	});
}

- (void)loadView {
	self.view = [[UIView alloc] init];
	if ([UIColor respondsToSelector:@selector(systemBackgroundColor)])
	{
		self.view.backgroundColor = [[UIColor class] systemBackgroundColor];
	}
	else
	{
		self.view.backgroundColor = [UIColor whiteColor];
	}
	self->_connectButton = [RMStartStopButton buttonWithType:UIButtonTypeCustom];
	self->_connectButton.translatesAutoresizingMaskIntoConstraints = NO;
	[self->_connectButton addTarget:self action:@selector(connectButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(vpnStatusDidChange:)
		       name:NEVPNStatusDidChangeNotification
		     object:nil];
	[self.view addSubview:self->_connectButton];
	NSLayoutConstraint *buttonSizeConstraint_Width = [self->_connectButton.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:0.5];
	buttonSizeConstraint_Width.priority = UILayoutPriorityDefaultHigh;
	NSLayoutConstraint *buttonSizeConstraint_Height = [self->_connectButton.widthAnchor constraintEqualToAnchor:self.view.heightAnchor multiplier:0.5];
	buttonSizeConstraint_Height.priority = UILayoutPriorityDefaultHigh;
	[NSLayoutConstraint activateConstraints:@[
		[self->_connectButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
		[self->_connectButton.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
		buttonSizeConstraint_Width,
		buttonSizeConstraint_Height,
		[self->_connectButton.widthAnchor constraintLessThanOrEqualToAnchor:self.view.widthAnchor multiplier:0.5],
		[self->_connectButton.widthAnchor constraintLessThanOrEqualToAnchor:self.view.heightAnchor multiplier:0.5],
	]];
}

- (void)loadManager:(void (^)(NETunnelProviderManager *))withManager {
	[self showDebugAlert:@"[1] loadManager" message:@"Calling loadAllFromPreferences..."];
	[NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:
		^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
		if (error)
		{
			[self showDebugAlert:@"[1] ERROR" message:[NSString stringWithFormat:@"loadAll: %@", error]];
			return;
		}
		[self showDebugAlert:@"[2] OK" message:[NSString stringWithFormat:@"Found %lu managers", (unsigned long)managers.count]];
		NETunnelProviderManager *mgr = managers.lastObject;
		NETunnelProviderProtocol *prot = nil;
		if (mgr)
		{
			if (mgr.enabled)
			{
				[mgr loadFromPreferencesWithCompletionHandler:
					^(NSError * _Nullable error) {
						if (error) [self showDebugAlert:@"[3] ERROR" message:[NSString stringWithFormat:@"load: %@", error]];
						withManager(mgr);
					}];
				return;
			}
			else
			{
				mgr.enabled = YES;
			}
		}
		else
		{
			mgr = [[NETunnelProviderManager alloc] init];
			prot = [[NETunnelProviderProtocol alloc] init];
			mgr.protocolConfiguration = prot;
			mgr.localizedDescription = @"Rumble";
			        prot.providerBundleIdentifier = @"app.valley6976.badger3313.ext";
			prot.serverAddress = @"localhost";
			mgr.enabled = YES;
		}
		[mgr saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
			if (error)
			{
				[self showDebugAlert:@"[4] ERROR" message:[NSString stringWithFormat:@"save: %@", error]];
				return;
			}
			[mgr loadFromPreferencesWithCompletionHandler:
				^(NSError * _Nullable error) {
					if (error)
					{
						[self showDebugAlert:@"[4b] ERROR" message:[NSString stringWithFormat:@"reload: %@", error]];
						return;
					}
					withManager(mgr);
				}];
		}];
	}];
}

- (void)connectButtonTapped:(id)sender {
      [self showDebugAlert:@"[0] BUTTON OK" message:@"Button tap received!"];
      [self loadManager: ^(NETunnelProviderManager *mgr)
      {
	      NEVPNStatus status = mgr.connection.status;
	      [self showDebugAlert:@"[5] Manager" message:[NSString stringWithFormat:@"VPN status: %ld", (long)status]];
	      if (status != NEVPNStatusConnected)
	      {
		      NSError *startError;
		      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		      NSDictionary * options = @{
			      @"Args": [RMRootViewController shellSplit:
			[@"ciadpi -i ::1 -p 8080 -x 2 " stringByAppendingString:[defaults objectForKey:@"Args"]]],
			      @"IPv6": [NSNumber numberWithBool:[defaults boolForKey:@"IPv6"]],
			      @"DNSServer": [defaults objectForKey:@"DNSServer"],
		      };
		      [mgr.connection startVPNTunnelWithOptions:options andReturnError:&startError];
		      if (startError) {
			      [self showDebugAlert:@"[6] ERROR" message:[NSString stringWithFormat:@"startVPN: %@", startError]];
		      } else {
			      [self showDebugAlert:@"[6] OK" message:@"VPN start requested!"];
		      }
		      [[NSNotificationCenter defaultCenter] removeObserver:self];
		      [[NSNotificationCenter defaultCenter]
			      addObserver:self
			         selector:@selector(vpnStatusDidChange:)
			             name:NEVPNStatusDidChangeNotification
			           object:mgr.connection];
	      }
	      else
	      {
		      [mgr.connection stopVPNTunnel];
	      }
      }];
}

- (void)vpnStatusDidChange:(NSNotification *)notification {
	NETunnelProviderSession *session = (NETunnelProviderSession *)[notification object];
	if (!session) return;
	NEVPNStatus status = session.status;
	NSLog(@"vpnStatusDidChange: %ld", (long)status);
	switch (status)
	{
	    case NEVPNStatusInvalid:
	    case NEVPNStatusDisconnected:
		[self->_connectButton setEnabled:YES];
		[self->_connectButton setActivated:NO];
		break;
	    case NEVPNStatusConnecting:
		[self->_connectButton setEnabled:NO];
		break;
	    case NEVPNStatusConnected:
		[self->_connectButton setEnabled:YES];
		[self->_connectButton setActivated:YES];
		break;
	    case NEVPNStatusReasserting:
		[self->_connectButton setEnabled:NO];
		break;
	    case NEVPNStatusDisconnecting:
		[self->_connectButton setEnabled:NO];
		break;
	    default:
		break;
	}
}

@end
