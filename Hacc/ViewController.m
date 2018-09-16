//
//  ViewController.m
//  Hacc
//
//  Created by Matthew Stallone on 9/15/18.
//  Copyright © 2018 Matthew Stallone. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () <ARSCNViewDelegate>

@property (nonatomic, strong) IBOutlet ARSCNView *sceneView;

@end

    
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Set the view's delegate
    self.sceneView.delegate = self;
    
    // Show statistics such as fps and timing information
    self.sceneView.showsStatistics = YES;
    
    // Create a new scene
    SCNScene *scene = [SCNScene scene];
    
    // Set the scene to the view
    self.sceneView.scene = scene;
    [self.sceneView setAutoenablesDefaultLighting:true];
    
    // Create the model
    model = [[[Inceptionv3 alloc] init] model];
    coreMLModel = [VNCoreMLModel modelForMLModel: model error:nil];
    
    // Create the model request
    coreMLRequest = [[VNCoreMLRequest alloc] initWithModel:coreMLModel completionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
        VNClassificationObservation *topResult = ((VNClassificationObservation *)(request.results[0]));
        //NSString *item = [NSString stringWithFormat: @"%f: %@", topResult.confidence, topResult.identifier];
        dispatch_async(dispatch_get_main_queue(), ^{
            self->label = topResult.identifier;
        });
        
    }];
    [coreMLRequest setImageCropAndScaleOption:VNImageCropAndScaleOptionCenterCrop];
    
    // Run the ml loop
    dispatch_async(dispatch_queue_create("hacc", NULL), ^{
        while (true) [self recognize];
    });
    
    // Register the tap recognizer
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap)];
    [self.view addGestureRecognizer:tapGestureRecognizer];
    
    UITapGestureRecognizer *twoFingerTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(twoFingerTap)];
    [twoFingerTapGestureRecognizer setNumberOfTouchesRequired:2];
    [self.view addGestureRecognizer:twoFingerTapGestureRecognizer];
    
    // Double tap recognizer
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(clearAll)];
    doubleTap.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:doubleTap];
    
    //
    [self addCrosshair];
    label = [NSString stringWithFormat:@"hello"];
    currentSpanishLabels = [[NSMutableArray alloc] init];
    currentEnglishLabels = [[NSMutableArray alloc] init];
    spanishPresent = false;
}

- (void) clearAll {
    label = [NSString stringWithFormat:@"hello"];
    currentSpanishLabels = [[NSMutableArray alloc] init];
    currentEnglishLabels = [[NSMutableArray alloc] init];
    spanishPresent = false;
    
    for (SCNNode * node in [self.sceneView.scene.rootNode childNodes]) {
        [node removeFromParentNode];
    }
}

- (void) twoFingerTap {
    for (SCNNode *node in currentEnglishLabels) {
        [node setHidden:!spanishPresent];
    }
    for (SCNNode *node in currentSpanishLabels) {
        [node setHidden:spanishPresent];
    }
    spanishPresent = !spanishPresent;
}
- (void) addCrosshair {
    SKShapeNode *horizontal = [SKShapeNode node];
    CGMutablePathRef horizontalPath = CGPathCreateMutable();
    CGPathMoveToPoint(horizontalPath, NULL, self.sceneView.bounds.size.width/2 - 12, self.sceneView.bounds.size.height/2);
    CGPathAddLineToPoint(horizontalPath, NULL, self.sceneView.bounds.size.width/2 + 12, self.sceneView.bounds.size.height/2);
    horizontal.path = horizontalPath;
    [horizontal setStrokeColor:[SKColor grayColor]];
    
    SKShapeNode *vertical = [SKShapeNode node];
    CGMutablePathRef verticalPath = CGPathCreateMutable();
    CGPathMoveToPoint(verticalPath, NULL, self.sceneView.bounds.size.width/2, self.sceneView.bounds.size.height/2 - 12);
    CGPathAddLineToPoint(verticalPath, NULL, self.sceneView.bounds.size.width/2, self.sceneView.bounds.size.height/2 + 12);
    vertical.path = verticalPath;
    [vertical setStrokeColor:[SKColor grayColor]];
    SKScene *scene = [[SKScene alloc] initWithSize:self.sceneView.bounds.size];
    [scene addChild: horizontal];
    [scene addChild: vertical];
    
    self.sceneView.overlaySKScene = scene;
    self.sceneView.overlaySKScene.hidden = NO;
    self.sceneView.overlaySKScene.scaleMode = SKSceneScaleModeResizeFill;
}

- (void) tap {
    CGPoint center = CGPointMake(self.sceneView.bounds.size.width/2, self.sceneView.bounds.size.height/2);
    
    NSArray *hitTestResults = [self.sceneView hitTest:center types:ARHitTestResultTypeFeaturePoint];
    ARHitTestResult *hitTestResult = [hitTestResults firstObject];
    
    matrix_float4x4 transform = hitTestResult.worldTransform;
    SCNVector3 position = SCNVector3Make(transform.columns[3][0], transform.columns[3][1], transform.columns[3][2]);
    
    NSString*currentLabel = label;
    SCNNode *textNode = [self textNode:currentLabel andPosition:position];
    
    [self.sceneView.scene.rootNode addChildNode:textNode];
    [textNode setHidden:spanishPresent];
    [currentEnglishLabels addObject:textNode];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *params = @{@"q": currentLabel,
                                 @"target": @"es",
                                 @"source": @"en",
                                 @"key": @"AIzaSyCsV-g8uUnUMhu001pd0lrbFdjvx1E5Ypo"};
        
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        [manager POST:@"https://translation.googleapis.com/language/translate/v2" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
            SCNNode *textNodeTranslated = [self textNode:responseObject[@"data"][@"translations"][0][@"translatedText"] andPosition:position];
            [textNodeTranslated setHidden:!self->spanishPresent];
            [self.sceneView.scene.rootNode addChildNode:textNodeTranslated];
            [self->currentSpanishLabels addObject:textNodeTranslated];
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSLog(@"Error: %@", error);
        }];
    });
}

- (SCNNode *) textNode:(NSString *) textLabel andPosition:(SCNVector3) position {
    
    //
    SCNPyramid *bottom = [SCNPyramid pyramidWithWidth:0.016 height:0.016 length:0.016];
    bottom.firstMaterial.diffuse.contents = [UIColor whiteColor];
    
    SCNPyramid *top = [SCNPyramid pyramidWithWidth:0.016 height:0.016 length:0.016];
    top.firstMaterial.diffuse.contents = [UIColor whiteColor];
    
    SCNText *text = [SCNText textWithString:textLabel extrusionDepth:0.02];
    UIFont *font = [UIFont fontWithName:@"Futura-Bold" size:0.13];
    text.font = font;
    
    text.alignmentMode = kCAAlignmentCenter;
    text.firstMaterial.diffuse.contents = [UIColor colorNamed:@"orange"];
    text.firstMaterial.specular.contents = [UIColor colorNamed:@"white"];
    [text.firstMaterial setDoubleSided:true];
    
    //[text setChamferRadius:0.01];

    SCNVector3 minBound = SCNVector3Zero, maxBound = SCNVector3Zero;
    [text getBoundingBoxMin:&minBound max:&maxBound];
    
    SCNNode *textNode = [SCNNode nodeWithGeometry:text];
    
    textNode.pivot = SCNMatrix4MakeTranslation( (maxBound.x - minBound.x)/2, minBound.y - 0.1, 0.02/2);
    textNode.scale = SCNVector3Make(0.2, 0.2, 0.2);
    
    SCNNode *topNode = [SCNNode nodeWithGeometry:top];
    
    SCNNode *bottomNode = [SCNNode nodeWithGeometry:bottom];
    bottomNode.rotation = SCNVector4Make(0, 0, 1, M_PI);
    bottomNode.pivot = SCNMatrix4MakeTranslation(0, 0.064, 0);
    
    SCNNode *parent = [SCNNode node];
    [parent addChildNode:bottomNode];
    [parent addChildNode:topNode];
    //
    CABasicAnimation *spin = [CABasicAnimation animationWithKeyPath:@"rotation"];
    spin.fromValue = [NSValue valueWithSCNVector4: SCNVector4Make(0, 1, 0, 0)];
    spin.toValue =  [NSValue valueWithSCNVector4: SCNVector4Make(0, 1, 0, 2 *M_PI)];
    spin.duration = 5;
    spin.repeatCount = INFINITY;
    
    [parent addAnimation:[SCNAnimation animationWithCAAnimation:spin] forKey:@"spin"];
    
    SCNBillboardConstraint *billboardConstraint = [[SCNBillboardConstraint alloc] init];
    billboardConstraint.freeAxes = SCNBillboardAxisY;
    
    SCNNode *node = [SCNNode node];
    [node addChildNode:parent];
    [node addChildNode:textNode];
    node.pivot = SCNMatrix4MakeTranslation(0, 0.031, 0);
    
    node.constraints = @[billboardConstraint];
    node.position = position;
    return node;
}

- (void) recognize {
    CVPixelBufferRef buffer = [self.sceneView.session.currentFrame capturedImage];
    if (buffer != nil) {
        CIImage *image = [[CIImage alloc] initWithCVPixelBuffer:buffer];
        
        VNImageRequestHandler *imageRequestHandler = [[VNImageRequestHandler alloc] initWithCIImage:image options:@{}];
        
        [imageRequestHandler performRequests:@[self->coreMLRequest] error:nil];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Create a session configuration
    ARWorldTrackingConfiguration *configuration = [ARWorldTrackingConfiguration new];

    // Run the view's session
    [self.sceneView.session runWithConfiguration:configuration];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // Pause the view's session
    [self.sceneView.session pause];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - ARSCNViewDelegate

/*
// Override to create and configure nodes for anchors added to the view's session.
- (SCNNode *)renderer:(id<SCNSceneRenderer>)renderer nodeForAnchor:(ARAnchor *)anchor {
    SCNNode *node = [SCNNode new];
 
    // Add geometry to the node...
 
    return node;
}
*/

- (void)session:(ARSession *)session didFailWithError:(NSError *)error {
    // Present an error message to the user
    
}

- (void)sessionWasInterrupted:(ARSession *)session {
    // Inform the user that the session has been interrupted, for example, by presenting an overlay
    
}

- (void)sessionInterruptionEnded:(ARSession *)session {
    // Reset tracking and/or remove existing anchors if consistent tracking is required
    
}

@end
