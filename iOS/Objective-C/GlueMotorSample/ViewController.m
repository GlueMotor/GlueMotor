//
//  ViewController.m
//  GlueMotorSample
//
//  Created by Kazuhisa "Kazu" Terasaki on 11/19/2016.
//  Copyright © 2016 Kazuhisa Terasaki All rights reserved.
//  https://github.com/gluemotor
//

#import "ViewController.h"
#import "GlueMotorCore.h"

@interface ViewController () <GlueMotorCoreDelegate>

@property (weak, nonatomic) IBOutlet UILabel *servo0Label;
@property (weak, nonatomic) IBOutlet UISwitch *servo0Switch;
@property (weak, nonatomic) IBOutlet UISlider *servo0Slider;
@property (weak, nonatomic) IBOutlet UILabel *servo1Label;
@property (weak, nonatomic) IBOutlet UISwitch *servo1Switch;
@property (weak, nonatomic) IBOutlet UISlider *servo1Slider;

@property (strong, nonatomic) GlueMotorCore *glueMotor;
@property (nonatomic) BOOL servo0PwmEnabled;
@property (nonatomic) NSTimeInterval servo0PulseWidth;
@property (nonatomic) BOOL servo1PwmEnabled;
@property (nonatomic) NSTimeInterval servo1PulseWidth;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    GlueMotorCore *gm = [GlueMotorCore sharedInstance];
    gm.delegate = self;
    self.glueMotor = gm;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.servo0PwmEnabled = self.servo0Switch.on;
    self.servo0PulseWidth = (NSTimeInterval)self.servo0Slider.value;
    self.servo1PwmEnabled = self.servo1Switch.on;
    self.servo1PulseWidth = (NSTimeInterval)self.servo1Slider.value;
    [self updatePulseWidth];
    [self updateLabels];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - IBAction

- (IBAction)servo0SwitchValueChanged:(UISwitch *)sender {
    self.servo0PwmEnabled = sender.on;
    [self updateLabels];
}

- (IBAction)servo0SliderValueChanged:(UISlider *)sender {
    self.servo0PulseWidth = (NSTimeInterval)sender.value;
    [self updateLabels];
}

- (IBAction)servo1SwitchValueChanged:(UISwitch *)sender {
    self.servo1PwmEnabled = sender.on;
    [self updateLabels];
}

- (IBAction)servo1SliderValueChanged:(UISlider *)sender {
    self.servo1PulseWidth = (NSTimeInterval)sender.value;
    [self updateLabels];
}

#pragma mark - Helper method

- (void)updatePulseWidth {
    GlueMotorCore *gm = self.glueMotor;
    [gm setPulseWidth:(self.servo0PwmEnabled ? self.servo0PulseWidth : 0.) forServo:0];
    [gm setPulseWidth:(self.servo1PwmEnabled ? self.servo1PulseWidth : 0.) forServo:1];
}

- (void)updateLabels {
    self.servo0Label.text = [NSString stringWithFormat:@"Servo 0 (L): %@", (self.servo0PwmEnabled ? [NSString stringWithFormat:@"%.03f%@", self.servo0PulseWidth * 1000., @"ms"] : @"OFF")];
    self.servo1Label.text = [NSString stringWithFormat:@"Servo 1 (R): %@", (self.servo1PwmEnabled ? [NSString stringWithFormat:@"%.03f%@", self.servo1PulseWidth * 1000., @"ms"] : @"OFF")];
}

#pragma mark - GlueMotorCoreDelegate

- (void)glueMotorCoreWillStartPWMCycle:(GlueMotorCore *)glueMotor {
    // NOTE: this delegate method will be called in Audio Queue thread, so don't call the UI related API from here.
    [self updatePulseWidth];
}

@end
