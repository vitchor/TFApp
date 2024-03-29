//
//  FirstViewController.m
//  DynaFocus
//
//  Created by Marcia  Rozenfeld on 7/10/12.
//  Copyright (c) 2012 Ufscar. All rights reserved.
//

#import "CameraView.h"
#import "PathView.h"
#import "iToast.h"
#import "AppDelegate.h"
#import <QuartzCore/QuartzCore.h>
#import "UIDevice+Hardware.h"
#import "ASIFormDataRequest.h"
#import "UIImage+FixOrientation.h"
#import "JSON.h"
#import "LoadView.h"

#define OK 0

@implementation CameraView

@synthesize shootButton, cancelButton, infoButton, mFocalPoints, previewView, imagePreviewView;

#pragma mark - View lifecycle
- (void)viewDidLoad
{
    pathView.enabled = true;
    isObserving = false;
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closePreviewImage:)] ;
    [previewView addGestureRecognizer:singleTap];
    
    
    [torchOneButton addTarget:self action:@selector(toggleTorchForFocusOne) forControlEvents:UIControlEventTouchUpInside];
    [torchTwoButton addTarget:self action:@selector(toggleTorchForFocusTwo) forControlEvents:UIControlEventTouchUpInside];
    
    [torchOneButton setImage:[UIImage imageNamed:@"Torch-Button-Off-NoStroke.png"] forState:UIControlStateNormal];
    [torchTwoButton setImage:[UIImage imageNamed:@"Torch-Button-Off-NoStroke.png"] forState:UIControlStateNormal];
    
    [self.cancelButton setImage:[UIImage imageNamed:@"CameraView-LeftButtonPressed.png"] forState:UIControlStateHighlighted];
    
    [self.shootButton setImage:[UIImage imageNamed:@"CameraView-ShootButtonPressed.png"] forState:UIControlStateHighlighted];
    
    [self.infoButton setImage:[UIImage imageNamed:@"CameraView-RightButtonPressed.png"] forState:UIControlStateHighlighted];
    
    tutorialView.cameraViewController = self;
    [tutorialView init];
    
    [super viewDidLoad];
}

-(void)closePreviewImage:(UITapGestureRecognizer *)gesture{
    
    [previewView setHidden:YES];
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.navigationController setNavigationBarHidden:YES animated:FALSE];
    
    
    [spinner startAnimating];
    [loadingView setHidden:NO];
    
    [super viewWillAppear:animated];
    
    [self.infoButton setEnabled:true];
    [self.cancelButton setEnabled:true];
    
    if(mFocalPoints.count==1)
        [self setTorchOn:(torchOnFocusPoints==2||torchOnFocusPoints==3)];
    else if(mFocalPoints.count==2)
        [self setTorchOn:(torchOnFocusPoints==1||torchOnFocusPoints==3)];
    
    mFOFIndex = 0;
    
    if (!mFrames) {
        mFrames = [[NSMutableArray alloc] init];
    } else {
        [mFrames removeAllObjects];
    }
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRotate:)name:UIDeviceOrientationDidChangeNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeChanged:) name:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil];
    
    pathView.cameraViewController = self;
    [pathView checkOrientations:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
    
    AppDelegate *delegate = [UIApplication sharedApplication].delegate;
    
    [self.shootButton setEnabled:tutorialView.isHidden];
    
    if (!captureSession) {
        [self startCaptureSession];
    } else {
        [captureSession startRunning];
        
        if (mCaptureDevice) {
            if (![mCaptureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus] || ![mCaptureDevice isFocusPointOfInterestSupported]) {
                [self disablePictureTaking];
            }
        }
        
        [spinner stopAnimating];
        [loadingView setHidden:YES];
    }
    
    [super viewDidAppear:animated];
    
    if([mFocalPoints count] > 0)
        [self updateFocusPoint];
    
    [ASIHTTPRequest setDefaultTimeOutSeconds:40];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (mToastMessage) {
        [mToastMessage removeToast:nil];
    }
    
	[super viewWillDisappear:animated];
    [captureSession stopRunning];
    
}

- (void)viewDidDisappear:(BOOL)animated
{
    
	[super viewDidDisappear:animated];

    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
    
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)updateFocusPoint {
    NSLog(@"UPDATE POINT: %d", mFOFIndex);
    NSError *error = nil;
    
    if ([mCaptureDevice lockForConfiguration:&error]) {
        
        if (mFocalPoints.count == 2) {
            NSLog(@"On Focus Update - current value for torchOnFocusPoints: %d",torchOnFocusPoints);
            if (torchOnFocusPoints == 1 || torchOnFocusPoints == 3) {
                NSLog(@"Turning freaking torch on!");
                isTorchOn = false;
                [self setTorchOn:!isTorchOn];
            } else {
                NSLog(@"Turning freaking torch off!");
                isTorchOn = true;
                [self setTorchOn:!isTorchOn];
            }
        }
        
        if (mFocalPoints.count == 1 || mFOFIndex == 1) {
            NSLog(@"On Focus Update - current value for torchOnFocusPoints: %d",torchOnFocusPoints);
            if (torchOnFocusPoints == 2 || torchOnFocusPoints == 3) {
                NSLog(@"Turning freaking torch on!");
                isTorchOn = false;
                [self setTorchOn:!isTorchOn];
            } else {
                NSLog(@"Turning freaking torch off!");
                isTorchOn = true;
                [self setTorchOn:!isTorchOn];
            }
        }
        
        if ([mCaptureDevice isExposurePointOfInterestSupported]) {
            [mCaptureDevice setExposurePointOfInterest:[[mFocalPoints objectAtIndex:mFOFIndex] CGPointValue]];
            
        } else {
            [self sendErrorReportWithMessage:@"CameraView.updateFocusPoint - exposure point is not supported!!"];
        }
        
        if ([mCaptureDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
            [mCaptureDevice setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            
        } else if ([mCaptureDevice isExposureModeSupported:AVCaptureExposureModeAutoExpose]) {
            [mCaptureDevice setFocusMode:AVCaptureExposureModeAutoExpose];
            
        } else {
            [self sendErrorReportWithMessage:@"CameraView.updateFocusPoint - exposure mode is not supported!!"];
        }
        
        if ([mCaptureDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
            [mCaptureDevice setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];

        } else {
            //[self sendErrorReportWithMessage:@"CameraView.updateFocusPoint - exposure mode is not supported!!"];
        }
        

        if ([mCaptureDevice isFocusPointOfInterestSupported]) {
            [mCaptureDevice setFocusPointOfInterest:[[mFocalPoints objectAtIndex:mFOFIndex] CGPointValue]];
            
        } else {
            [self sendErrorReportWithMessage:@"CameraView.updateFocusPoint - focus point is not supported!!"];
            [self disablePictureTaking];
        }
        if ([mCaptureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
            [mCaptureDevice setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
            
        } else {
            [self sendErrorReportWithMessage:@"CameraView.updateFocusPoint - focus mode is not supported!!"];
            [self disablePictureTaking];
        }
        
        // Releases the lock
        [mCaptureDevice unlockForConfiguration];
    } else {
        [self sendErrorReportWithMessage:@"CameraView.updateFocusPoint - mCaptureDevice couldn't be locked"];
    }

}

- (void)disablePictureTaking {
    if (self.navigationItem.rightBarButtonItem.enabled) {
        [self.shootButton setEnabled:false];
        [self.infoButton setEnabled:false];
        [self.cancelButton setEnabled:false];
        
        [self showOkAlertWithMessage:@"Your device does not support focus point settings." andTitle:@"Sorry"];
    }
}

- (void)startCaptureSession {
	
    // Create Session
    captureSession = [[AVCaptureSession alloc] init];
    
    NSString *device = [[UIDevice currentDevice] platform];
    
    if ([device isEqualToString:@"iPhone1,1"] || [device isEqualToString:@"iPhone1,2"] || [device isEqualToString:@"iPhone2,1"] || [device isEqualToString:@"iPhone3,1"] || [device isEqualToString:@"iPhone3,2"] || [device isEqualToString:@"iPhone3,3"]) {
        
        //Device is older than iPhone 4s
        
        if ([captureSession canSetSessionPreset: AVCaptureSessionPresetHigh]) {
            [captureSession setSessionPreset:AVCaptureSessionPresetHigh];
            captureSession.sessionPreset = AVCaptureSessionPresetHigh;
            
        } else if ([captureSession canSetSessionPreset: AVCaptureSessionPresetMedium]) {
            [captureSession setSessionPreset:AVCaptureSessionPresetMedium];
            captureSession.sessionPreset = AVCaptureSessionPresetMedium;
        }
        
    } else {
        
        // Device is iPhone 4s or 5
        
        if ([captureSession canSetSessionPreset: AVCaptureSessionPreset1920x1080]) {
            [captureSession setSessionPreset:AVCaptureSessionPreset1920x1080];
            captureSession.sessionPreset = AVCaptureSessionPreset1920x1080;
            
        } else if ([captureSession canSetSessionPreset: AVCaptureSessionPresetHigh]) {
            [captureSession setSessionPreset:AVCaptureSessionPresetHigh];
            captureSession.sessionPreset = AVCaptureSessionPresetHigh;
            
        }
    }
    
    
    // Find CaptureDevice
    NSArray *devices = [AVCaptureDevice devices];
    
    for (AVCaptureDevice *device in devices){
        if ([device hasMediaType:AVMediaTypeVideo]){
            if ([device position] == AVCaptureDevicePositionBack) {
                mCaptureDevice = device;
                break;
            }
        }
        
    }
    if (!mCaptureDevice) {
        [self sendErrorReportWithMessage:@"CameraView.startCaptureSession - couldn't find an AVCaptureDevice with AVMediaTypeVideo, AVCaptureDevicePositionBack"];
    }
    
    
    // Set initial focus point
    [self updateFocusPoint];
    
    // Create and add DeviceInput to Session
    NSError *error = nil;
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:mCaptureDevice error:&error];
    
    if ([captureSession canAddInput:deviceInput]) {
        [captureSession addInput:deviceInput];
    } else {
        [self sendErrorReportWithMessage:@"CameraView.startCaptureSession - couldn't add the device input to the actual AVCaptureSession"];
    }
    
    // Create/add StillImageOutput, get connection and add handler
    NSMutableDictionary *outputSettings = [[NSMutableDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG, AVVideoCodecKey, nil];
    

    mStillImageOutput = [[AVCaptureStillImageOutput alloc] init];

    [mStillImageOutput setOutputSettings:outputSettings];

    [captureSession addOutput:mStillImageOutput];

    
    
    //Get connection
    mVideoConnection = nil;

    for (AVCaptureConnection *connection in mStillImageOutput.connections) {

        for (AVCaptureInputPort *port in [connection inputPorts]) {

            if ([[port mediaType] isEqual:AVMediaTypeVideo]) {

                mVideoConnection = connection;
                break;
            }
        }
        
        if (mVideoConnection) {break;}
    }
    
    
    if (!mVideoConnection) {
         [self sendErrorReportWithMessage:@"CameraView.startCaptureSession - couldn't get a AVCaptureConnection with a port that is equal to AVMediaTypeVideo"];
    }

    [captureSession startRunning];

    // Showing preview layer
    AVCaptureVideoPreviewLayer *layer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession];

    layer.videoGravity = AVLayerVideoGravityResizeAspectFill;

    layer.frame = cameraView.frame;
    NSLog(@"CameraView is ready");
    [cameraView.layer addSublayer:layer];
    NSLog(@"CameraView is added");

    [spinner stopAnimating];
    [loadingView setHidden:YES];
    
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"adjustingFocus"]) {
        BOOL adjustingFocus = [[change objectForKey:NSKeyValueChangeNewKey] isEqualToNumber:[NSNumber numberWithInt:1]];
        
        NSLog(@"ADJUSTING FOCUS");
        
        if(!adjustingFocus) {
            NSLog(@"FOCUS IS GOOD");
            
            // Capture with handler
            NSLog(@"TAKING PICTURE...");
            
            [self capture];
            

        }
    }
}

- (void) capture {
    
    if (mVideoConnection && [mVideoConnection isVideoOrientationSupported]){
        
        UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
        
        if(orientation == UIDeviceOrientationFaceUp || orientation == UIDeviceOrientationFaceDown){
            
            if(pathView.lastOrientation==UIDeviceOrientationPortrait ||
               pathView.lastOrientation==UIDeviceOrientationPortraitUpsideDown ||
               pathView.lastOrientation==UIDeviceOrientationLandscapeLeft ||
               pathView.lastOrientation==UIDeviceOrientationLandscapeRight){
                
                [mVideoConnection setVideoOrientation: pathView.lastOrientation];
            }
            else{
                [mVideoConnection setVideoOrientation:UIDeviceOrientationPortrait];
            }
        }
        else
        {
            if(orientation == UIDeviceOrientationUnknown)
                [mVideoConnection setVideoOrientation:UIDeviceOrientationPortrait];
            else
                [mVideoConnection setVideoOrientation:orientation];
        }
    }
    
    if (mStillImageOutput) {
        
        [mStillImageOutput captureStillImageAsynchronouslyFromConnection:mVideoConnection completionHandler:
         ^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
             
             if (error) {
                 [self sendErrorReportWithMessage:error.localizedDescription];
                 [self showOkAlertWithMessage:@"The app is not ready to take pictures on your device yet, we're releasing an update soon. Please excuse us :( " andTitle:@"Sorry"];
                 
             } else {
                 CFDictionaryRef exifAttachments = CMGetAttachment(imageDataSampleBuffer, kCGImagePropertyExifDictionary, NULL);
                 
                 if (exifAttachments) {
                     
                     NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                     UIImage *image = [[UIImage alloc] initWithData:imageData] ;
                     
                     
                     if ((image.size.height == 1920.00 && image.size.width == 1080.00) || (image.size.height == 1080.00 && image.size.width == 1920.00)) {
                        
                         CGRect rect = CGRectMake(155,
                                                  0,
                                                  1475,
                                                  1080);
                         
                         CGImageRef imageRef = CGImageCreateWithImageInRect(image.CGImage, rect);
                         image = [UIImage imageWithCGImage:imageRef scale:16.0f orientation:image.imageOrientation];
                         CGImageRelease(imageRef);
                             
                         
                     } else if ((image.size.height == 720.00 && image.size.width == 1280.00) || (image.size.height == 1280.00 && image.size.width == 720.00)) {
                         
                         CGRect rect = CGRectMake(103,
                                                  0,
                                                  983,
                                                  720);

                         
                         CGImageRef imageRef = CGImageCreateWithImageInRect(image.CGImage, rect);
                         image = [UIImage imageWithCGImage:imageRef scale:1.0f orientation:image.imageOrientation];
                         CGImageRelease(imageRef);
                         
                     }
                     
                     [mFrames addObject:image];
                     
                     NSLog(@"DONE! ");
                     
                     mFOFIndex = mFOFIndex + 1;
                     
                     if (mFOFIndex < [mFocalPoints count]) {
                         [self updateFocusPoint];
                     } else {
                         NSLog(@" FINISHED PICTURE");
                         
                         isTorchOn = true;
                         [self setTorchOn:!isTorchOn];
                         
                         pathView.enabled = true;

                         
                         
                         ///// SEND REQUEST WITH THE IMAGES /////
                         
                         if (isObserving) {
                             [mCaptureDevice removeObserver:self forKeyPath:@"adjustingFocus"];
                             isObserving = NO;
                         }
                         
                         //NSURL *webServiceUrl = [NSURL URLWithString:[[NSString alloc] initWithFormat: @"http://ec2-54-245-78-110.us-west-2.compute.amazonaws.com/s/test/"]];
                         
                         NSURL *webServiceUrl = [NSURL URLWithString:[[NSString alloc] initWithFormat: @"http://192.168.0.119:8000/s/test/"]];
                         
                         NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
                         
                         NSString *userId = [userDefaults objectForKey:@"user_id"];

                         ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:webServiceUrl];
                         if (userId) {
                             [request setPostValue:userId forKey:@"user_id"];
                         }
                         [request setDelegate:self];
                        
                         for (int i = 0; i < [mFrames count]; i++)
                         {
                             UIImage *image = [[mFrames objectAtIndex:i] fixOrientation];
                             
                             NSLog(@"Uploading image %d with size: %f %f ", i, image.size.width, image.size.height);
                             
                             
                             NSString *imagePath = [[NSString alloc] initWithFormat:@"Documents/image_%d.jpg", i];
                             
                             NSString  *jpgPath = [NSHomeDirectory() stringByAppendingPathComponent:imagePath];
                             
                             // Write a UIImage to JPEG with minimum compression (best quality)
                             [UIImageJPEGRepresentation(image, 0.5) writeToFile:jpgPath atomically:YES];
                             
                             NSString *photoPath = [NSHomeDirectory() stringByAppendingPathComponent:imagePath];
                             
                             
                             // Add all the post values
                             
                             CGPoint touchPoint = [(NSValue *)[self.mFocalPoints objectAtIndex:i] CGPointValue];
                             
                             NSNumber *pointX = [[NSNumber alloc] initWithInt:touchPoint.x*100];
                             NSNumber *pointY = [[NSNumber alloc] initWithInt:touchPoint.y*100];
                             
                             NSString *frameFocalPointX = [[NSString alloc] initWithFormat:@"frame_focal_point_x_%d", i];
                             NSString *frameFocalPointY = [[NSString alloc] initWithFormat:@"frame_focal_point_y_%d", i];
                             
                             [request setPostValue:pointX forKey:frameFocalPointX];
                             [request setPostValue:pointY forKey:frameFocalPointY];
                  
                             
                             NSString *fileName = [[NSString alloc] initWithFormat:@"image_%d.jpeg", i];
                             NSString *keyName = [[NSString alloc] initWithFormat:@"apiupload_%d", i];
                             
                             // Add the image file to the request
                             [request setFile:photoPath withFileName:fileName andContentType:@"Image/jpeg" forKey:keyName];
                             
                       
                             //[fof_size release];
                             
                         }
                         //[request setUseSessionPersistence:YES];
                         [request startAsynchronous];
                         [LoadView loadViewOnView:self.view withText:@"Creating..."];
                         NSError *error = [request error];
                         if (!error) {
                             NSString *response = [request responseString];
                         } else {
                             NSLog(error.description);
                         }

                     }
                     
                 }
             }
             
         }];
    } else {
        [self sendErrorReportWithMessage:@"CameraView.observeValueForKeyPath - the ImageOutput was null when using it to capture."];
    }
}

- (void)requestFinished:(ASIHTTPRequest *)request {
    NSLog(@"REQUEST FINISHED");
    
    NSDictionary *jsonValues = [request.responseString JSONValue];
    
    NSString *userId = [jsonValues objectForKey:@"user_id"];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:userId forKey:@"user_id"];
    [userDefaults synchronize];
    
    NSURL *url = [NSURL URLWithString: [jsonValues objectForKey:@"url"]];
    
    UIImage *image = [UIImage imageWithData: [NSData dataWithContentsOfURL:url]];
    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
    
    [previewView setHidden:NO];
    [imagePreviewView setImage:image];
    
    NSLog(@"MESSAGE %@",request.responseString);
    [LoadView removeFromView:self.view];
    
    [self showToast:@"Image was saved to your photo album"];
    
    mFOFIndex = 0;
    [mFrames removeAllObjects];
    
    [self.shootButton setEnabled:YES];
    [self.infoButton setEnabled:YES];
    [self.cancelButton setEnabled:YES];
    
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    NSError *error = [request error];
    [LoadView removeFromView:self.view];
    [self showToast:@"Connection Failed"];
}

-(void) torchToggle {

    isTorchOn = !isTorchOn;
    [self setTorchOn:isTorchOn];
}

// Logic for variable torchOnFocusPoints:
// 0: no torch on any point
// 1: torch on focus point 2
// 2: torch on focus point 1
// 3: torch on both focus points

-(void) toggleTorchForFocusTwo {
    
    if (torchOnFocusPoints == 1 || torchOnFocusPoints == 3) {
        // torch for focus point 2 is on, turn it off immediately
        isTorchOn = true;
        [self setTorchOn:!isTorchOn];
        [torchTwoButton setImage:[UIImage imageNamed:@"Torch-Button-Off-NoStroke.png"] forState:UIControlStateNormal];
        torchOnFocusPoints -= 1;
    } else if (torchOnFocusPoints == 0 || torchOnFocusPoints == 2) {
        // torch for focus point 2 is off, turn it on immediately
        torchOnFocusPoints += 1;
        isTorchOn = false;
        [self setTorchOn:!isTorchOn];
        [torchTwoButton setImage:[UIImage imageNamed:@"Torch-Button-On-NoStroke.png"] forState:UIControlStateNormal];
    } else {
        torchOnFocusPoints = 1;
        isTorchOn = false;
        [self setTorchOn:!isTorchOn];
    }
    NSLog(@"Current value for torchOnFocusPoints: %d",torchOnFocusPoints);
}

-(void) toggleTorchForFocusOne {
    if (torchOnFocusPoints == 2 || torchOnFocusPoints == 3) {
        // torch for focus point 1 is on, turn it off when taking second pic
        torchOnFocusPoints -= 2;
        [torchOneButton setImage:[UIImage imageNamed:@"Torch-Button-Off-NoStroke.png"] forState:UIControlStateNormal];
        
        if(mFocalPoints.count==1){
            isTorchOn=true;
            [self setTorchOn:!isTorchOn];
        }
    } else if (torchOnFocusPoints == 0 || torchOnFocusPoints == 1) {
        // torch for focus point 1 is off, turn it on when taking second pic
        torchOnFocusPoints += 2;
        [torchOneButton setImage:[UIImage imageNamed:@"Torch-Button-On-NoStroke.png"] forState:UIControlStateNormal];
        
        if(mFocalPoints.count==1){
            isTorchOn=false;
            [self setTorchOn:!isTorchOn];
        }
    }
    NSLog(@"Current value for torchOnFocusPoints: %d",torchOnFocusPoints);
}

-(void)showTutorial
{
    
    if (mToastMessage) {
        [mToastMessage removeToast:nil];
        mToastMessage = nil;
    }
    
    [tutorialView loadTutorial:YES];
}

-(void)goBackToLastController
{
    AppDelegate* appDelegate = [UIApplication sharedApplication].delegate;
    [appDelegate goBackToLastController];
}

-(void)clearPoints
{
    if(mFocalPoints!=nil)
        [mFocalPoints removeAllObjects];
    
    [self setTorchOn:NO];
}

-(void)addObserverToFocus
{
    
    mFocalPoints = [pathView getPoints];
    
    [self.shootButton setEnabled:false];
    
    if ([mFocalPoints count] > 1) {
        
        if (mFOFIndex == 0 && ![mCaptureDevice isAdjustingExposure] && ![mCaptureDevice isAdjustingFocus]) {
           
            [self capture];
            isObserving = YES;
            [mCaptureDevice addObserver:self forKeyPath:@"adjustingFocus" options:NSKeyValueObservingOptionNew context:nil];
        } else {
            [self.infoButton setEnabled:false];
            [self.cancelButton setEnabled:false];
            
            pathView.enabled = false;
            
            [self updateFocusPoint];
        
            isObserving = YES;
            [mCaptureDevice addObserver:self forKeyPath:@"adjustingFocus" options:NSKeyValueObservingOptionNew context:nil];
        }
    } else {
        [self showAlertBaloon];
    }
}

- (void) showAlertBaloon {
    
	NSString *alertTitle = @"Add more points";
	NSString *alertMsg =@"Add 2 focus points by tapping the screen.";
	NSString *alertButton1 = @"OK";
	
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:alertTitle message:alertMsg delegate:self cancelButtonTitle:alertButton1 otherButtonTitles:nil] ;
    // optional - add more buttons:
	[alert setTag:OK];
    [alert show];
	
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if ([alertView tag] == OK) {
        if (buttonIndex == 0) {
			 [self.shootButton setEnabled:true];
        }
    }
}

-(void)showOkAlertWithMessage:(NSString *)message andTitle:(NSString *)title
{
    NSString *alertButton = @"OK";
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:alertButton otherButtonTitles:nil] ;
    [alert show];


}

- (IBAction)cancelAction:(UIButton *)sender {
    
   [self goBackToLastController];
}

- (IBAction)shootAction:(UIButton *)sender {
    
    [self addObserverToFocus];
}

- (IBAction)helpAction:(UIButton *)sender {

    [self showTutorial];
}

- (void)showToast:(NSString *)text {

    iToast *toastMessage = [iToast makeText:NSLocalizedString(text, @"")];
    [[toastMessage setDuration:iToastDurationNormal] show];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (void)sendErrorReportWithMessage:(NSString *)message
{
    //NSString *error = [[NSString alloc] initWithFormat:@"Error: %@.", message];
    //[TestFlight passCheckpoint:error];
    //[error release];
}

- (NSUInteger) supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (void) didRotate:(NSNotification *)notification
{
    [pathView checkOrientations:NO];
}

-(IBAction)volumeChanged:(id)sender{
    if(self.shootButton.isEnabled)
        [self addObserverToFocus];
}

- (void) setTorchOn:(BOOL)isOn
{
    [mCaptureDevice lockForConfiguration:nil]; //you must lock before setting torch mode
    [mCaptureDevice setTorchMode:isOn ? AVCaptureTorchModeOn : AVCaptureTorchModeOff];
    [mCaptureDevice unlockForConfiguration];
}

@end
