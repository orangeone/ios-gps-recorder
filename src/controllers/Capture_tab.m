#import "controllers/Capture_tab.h"

#import "App_delegate.h"
#import "GPS.h"
#import "controllers/Note_taking_controller.h"
#import "macro.h"


@interface Capture_tab ()
- (void)gps_switch_changed;
- (void)gps_switch_changed;
- (void)update_gui;
- (void)start_timer;
- (void)add_note;
@end


@implementation Capture_tab

@synthesize old_location = old_location_;

#pragma mark -
#pragma mark Life

- (id)init
{
	if (!(self = [super init]))
		return nil;

	self.title = @"Capture";

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(did_enter_background)
		name:@"UIApplicationDidEnterBackgroundNotification" object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(did_become_active)
		name:@"UIApplicationWillEnterForegroundNotification" object:nil];

	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[timer_ invalidate];
	if (watching_)
		[[GPS get] remove_watcher:self];
	[start_switch_ removeTarget:self action:@selector(gps_switch_changed)
		forControlEvents:UIControlEventValueChanged];
	[record_type_switch_ removeTarget:self
		action:@selector(record_type_switch_changed)
		forControlEvents:UIControlEventValueChanged];
	[clock_ release];
	[ago_ release];
	[note_ release];
	[capabilities_ release];
	[movement_ release];
	[start_switch_ release];
	[altitude_ release];
	[precission_ release];
	[latitude_ release];
	[longitude_ release];
	[start_title_ release];
	[old_location_ release];
	[record_type_switch_ release];
	[explanation_label_ release];
    [start_ release];
	[super dealloc];
}

- (void)loadView
{
	[super loadView];

	UIImageView *background = [[UIImageView alloc]
		initWithImage:[UIImage imageNamed:@"back.jpg"]];
	[self.view addSubview:background];
	[background release];

	note_ = [[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];
	note_.frame = CGRectMake(5, 70, 310, 135);
	[note_ setTitle:@"" forState:UIControlStateNormal];
	[note_ addTarget:self action:@selector(add_note)
		forControlEvents:UIControlEventTouchUpInside];
	_MAKE_BUTTON_LABEL_COLOR(note_.titleLabel);
	[self.view addSubview:note_];

	start_title_ = [[UILabel alloc] initWithFrame:CGRectMake(10, 20, 210, 30)];
	start_title_.text = @"1";
	_MAKE_DEFAULT_LABEL_COLOR(start_title_);
	[self.view addSubview:start_title_];

	start_switch_ = [[UISwitch alloc]
		initWithFrame:CGRectMake(220, 20, 100, 30)];
	[start_switch_ addTarget:self action:@selector(gps_switch_changed)
		forControlEvents:UIControlEventValueChanged];
	[self.view addSubview:start_switch_];

	UILabel *record_type_title = [[UILabel alloc]
		initWithFrame:CGRectMake(10, 245, 210, 30)];
	record_type_title.text = @"全てのGPSデータを保存";
	_MAKE_DEFAULT_LABEL_COLOR(record_type_title);
	[self.view addSubview:record_type_title];
	[record_type_title release];

	record_type_switch_ = [[UISwitch alloc]
		initWithFrame:CGRectMake(220, 245, 100, 30)];
	[record_type_switch_ addTarget:self
		action:@selector(record_type_switch_changed)
		forControlEvents:UIControlEventValueChanged];
	[self.view addSubview:record_type_switch_];
	record_type_switch_.on = [GPS get].save_all_positions;

	explanation_label_ = [[UILabel alloc]
		initWithFrame:CGRectMake(10, 210, 300, 25)];
	explanation_label_.text = @"上のボタンをタッチしてGPSデータを収集しましょう";
	explanation_label_.adjustsFontSizeToFitWidth = YES;
	_MAKE_DEFAULT_LABEL_COLOR(explanation_label_);
	[self.view addSubview:explanation_label_];

	longitude_ = [[UILabel alloc] initWithFrame:CGRectMake(5, 5, 300, 20)];
	longitude_.text = @"2";
	_MAKE_BUTTON_LABEL_COLOR(longitude_);
	[note_ addSubview:longitude_];

	latitude_ = [[UILabel alloc] initWithFrame:CGRectMake(5, 25, 300, 20)];
	latitude_.text = @"3";
	_MAKE_BUTTON_LABEL_COLOR(latitude_);
	[note_ addSubview:latitude_];

	precission_ = [[UILabel alloc] initWithFrame:CGRectMake(5, 45, 300, 20)];
	precission_.text = @"4";
	_MAKE_BUTTON_LABEL_COLOR(precission_);
	[note_ addSubview:precission_];

	altitude_ = [[UILabel alloc] initWithFrame:CGRectMake(5, 65, 300, 20)];
	altitude_.text = @"5";
	_MAKE_BUTTON_LABEL_COLOR(altitude_);
	[note_ addSubview:altitude_];

	ago_ = [[UILabel alloc] initWithFrame:CGRectMake(5, 85, 300, 20)];
	ago_.text = @"6";
	_MAKE_BUTTON_LABEL_COLOR(ago_);
	[note_ addSubview:ago_];

	movement_ = [[UILabel alloc] initWithFrame:CGRectMake(5, 105, 300, 20)];
	movement_.text = @"7";
	_MAKE_BUTTON_LABEL_COLOR(movement_);
	[note_ addSubview:movement_];

	capabilities_ = [[UILabel alloc]
		initWithFrame:CGRectMake(10, 273, 300, 79)];
	capabilities_.text = @"";
	capabilities_.numberOfLines = 0;
	capabilities_.font = [UIFont systemFontOfSize:15];
	_MAKE_DEFAULT_LABEL_COLOR(capabilities_);
	[self.view addSubview:capabilities_];

	clock_ = [[UILabel alloc] initWithFrame:CGRectMake(0, 351, 320, 60)];
	clock_.text = @"00:00:00";
	clock_.numberOfLines = 1;
	clock_.textAlignment = UITextAlignmentCenter;
	clock_.adjustsFontSizeToFitWidth = YES;
	clock_.font = [UIFont systemFontOfSize:50];
	_MAKE_DEFAULT_LABEL_COLOR(clock_);
	[self.view addSubview:clock_];
    
    start_ = [[NSDate date] retain];
}

/** The view is going to be shown. Update it.
 */
- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

	start_switch_.on = [GPS get].gps_is_on;
	[self update_gui];

	[self start_timer];
}

/** The view is going to dissappear.
 */
- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];

	[timer_ invalidate];
	timer_ = 0;
}

#pragma mark -
#pragma mark Methods

/// User toggled on/off GUI switch.
- (void)gps_switch_changed
{
	GPS *gps = [GPS get];

	if ([start_switch_ isOn]) {
		if (![gps start]) {
			start_switch_.on = false;
			[self warn:@"GPS起動できません！" title:@"GPS"];
		} else {
			[gps add_watcher:self];
			watching_ = YES;
		}
	} else {
		if (watching_)
			[gps remove_watcher:self];
		watching_ = NO;
		[gps stop];
	}

	[self update_gui];
}

/// User toggled the record all/single switch.
- (void)record_type_switch_changed
{
	[GPS get].save_all_positions = record_type_switch_.on;
	[self update_gui];
}

/** Handles updating the gui labels and other state.
 */
- (void)update_gui
{
	// Clock time.
	//NSDate *now = [NSDate date];
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setTimeStyle:NSDateFormatterMediumStyle];
    NSTimeInterval tid = [[NSDate date] timeIntervalSinceDate:start_];
    NSDate *des = [[NSDate alloc] initWithTimeIntervalSince1970:tid];
	clock_.text = [formatter stringFromDate:des];
    clock_.text = [NSString stringWithFormat:@"%02li:%02li:%02li",
                   lround(floor(tid / 3600.)) % 100,
                   lround(floor(tid / 60.)) % 60,
                   lround(floor(tid)) % 60];
	[formatter release];

	// State of capture.
	if (start_switch_.on)
		start_title_.text = @"GPS 読み込み...";
	else
		start_title_.text = @"GPS ×";

	// Visibility of the explanation for the second switch.
	[UIView beginAnimations:nil context:nil];
	explanation_label_.alpha = (record_type_switch_.on) ? 0 : 1;
	[UIView commitAnimations];

	// Device information. Update only if needed, it doesn't change at runtime.
	if (capabilities_.text.length < 1) {
		if (g_is_multitasking) {
			capabilities_.text = [NSString stringWithFormat:@"Multitasking "
				@"available. Location changes %@. Region monitoring %@.",
				g_location_changes ? @"available" : @"not available",
				g_region_monitoring ? @"available" : @"not available"];
		} else {
			capabilities_.text = @"Your device doesn't support multitasking. "
				@"GPS positions will only be captured while you have this "
				@"program on.";
		}
	}

	// Last location.
	CLLocation *location = [GPS get].last_pos;
	if (!location) {
		longitude_.text = @"最新の位置情報がありません。";
		latitude_.text = @"";
		precission_.text = @"";
		altitude_.text = @"";
		ago_.text = @"";
		movement_.text = @"";
		return;
	}

	longitude_.text = [NSString stringWithFormat:@"経度: %@",
		[GPS degrees_to_dms:location.coordinate.longitude latitude:NO]];

	latitude_.text = [NSString stringWithFormat:@"緯度: %@",
		[GPS degrees_to_dms:location.coordinate.latitude latitude:YES]];

	const CLLocationAccuracy v = (location.horizontalAccuracy +
		location.horizontalAccuracy) / 2.0;
	precission_.text = [NSString stringWithFormat:@"精度: %0.0fm", v];

	altitude_.text = (location.verticalAccuracy < 0) ? @"高度: ?" :
		[NSString stringWithFormat:@"高度: %0.0fm +/- %0.1fm",
			location.altitude, location.verticalAccuracy];

	NSTimeInterval diff = [[NSDate date] timeIntervalSinceDate:location.timestamp];
	ago_.text = [NSString stringWithFormat:@"%@ 前", (diff > 60 ?
		[NSString stringWithFormat:@"%d 分", (int)diff / 60] :
		[NSString stringWithFormat:@"%d 秒", (int)diff])];

	if ([self.old_location
			respondsToSelector:@selector(distanceFromLocation:)]) {
		movement_.text = [NSString
			stringWithFormat:@"位置変更 %0.0f メートル",
			[self.old_location distanceFromLocation:location]];
		if (![self.old_location.timestamp isEqualToDate:location.timestamp])
			self.old_location = location;
	} else {
		movement_.text = self.old_location ? @"" : @"最初の位置!";
		self.old_location = location;
	}
}

/** Starts the GUI update timer every second.
 * Only if there is no previous timer attached to the class variable...
 */
- (void)start_timer
{
	if (!timer_)
		timer_ = [NSTimer scheduledTimerWithTimeInterval:1 target:self
			selector:@selector(update_gui) userInfo:nil repeats:YES];
}

/** The application did become active. See if we have to reenable the timers.
 */
- (void)did_become_active
{
	if (reenable_timers_) {
		DLOG(@"Did become active, re-enabling GUI timer.");
		[self start_timer];
		reenable_timers_ = NO;
	}
}

/** The application went into background.
 * Disable the timers and make a note to reenable them when coming back.
 */
- (void)did_enter_background
{
	if (timer_) {
		DLOG(@"Entering background, disabling GUI timer.");
		[timer_ invalidate];
		timer_ = nil;
		reenable_timers_ = YES;
	}
}

/** Captures the last position and offers the user to input a note.
 * The note won't be added if the gps is off, or there was no last
 * input available. The purpose is to have a valid note location.
 */
- (void)add_note
{
	if (![GPS get].gps_is_on) {
		[self warn:@"GPSを起動してください。"
			title:@"GPS ×"];
		return;
	}

	CLLocation *location = [GPS get].last_pos;
	if (!location) {
		[self warn:@"GPSが位置情報を受信するまでお待ちください。"
			title:@"GPSデータがありません"];
		return;
	}

	Note_taking_controller *controller = [Note_taking_controller new];
	controller.location = location;
	[self presentModalViewController:controller animated:YES];
	[controller release];
}

#pragma mark -
#pragma mark KVO

/** Watches GPS changes.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
	change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqual:[GPS key_path]])
		[self update_gui];
	else
		[super observeValueForKeyPath:keyPath ofObject:object change:change
			context:context];
}

@end

// vim:tabstop=4 shiftwidth=4 syntax=objc
