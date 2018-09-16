//
//  ViewController.h
//  Hacc
//
//  Created by Matthew Stallone on 9/15/18.
//  Copyright © 2018 Matthew Stallone. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SceneKit/SceneKit.h>
#import <SpriteKit/SpriteKit.h>
#import <ARKit/ARKit.h>
#import <Vision/Vision.h>
#import <CoreML/CoreML.h>
#import "Inceptionv3.h"

#import "AFNetworking.h"

@interface ViewController : UIViewController {
    MLModel *model;
    VNCoreMLModel *coreMLModel;
    VNCoreMLRequest * coreMLRequest;
    dispatch_queue_t coreMLQueue;
    
    bool spanishPresent;
    NSString *label;
    NSMutableArray *currentEnglishLabels, *currentSpanishLabels;
}

@end
