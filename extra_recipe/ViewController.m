//
//  ViewController.m
//  multipath_kfree
//
//  Created by q on 6/1/18.
//  Copyright © 2018 kjljkla. All rights reserved.
//

#import "ViewController.h"
#include "jailbreak.h"
extern char* stdoutPath;
extern boolean_t debuggerAttached;
NSTimer* timer;

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextView *logView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    if(!debuggerAttached) {
        timer = [NSTimer scheduledTimerWithTimeInterval:0.5f repeats:YES block:^(NSTimer *timer){
            
            NSString* contents_out = @"";
            contents_out = [[NSString alloc] initWithContentsOfFile:[NSString stringWithUTF8String:stdoutPath]];
            
            [self performSelectorOnMainThread:@selector(updateUI:) withObject:contents_out waitUntilDone:NO];
        }];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    if(debuggerAttached) {
        self.logView.text = @"Thanks for debugging me in Xcode";
    }
    [NSThread detachNewThreadWithBlock:^(void){
        jb_go();
        printf("We now are %s\n", getlogin());
        if(!debuggerAttached) {
            [timer invalidate];
        }
    }];
}
-(void)updateUI:(NSString*)contents{
    self.logView.text = contents;
    [self.logView scrollRangeToVisible:NSMakeRange(self.logView.text.length, 0)];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
