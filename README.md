# SFPSDWriter

SFPSDWriter is an Objective-C library for writing PSD files. Here at Shiny Frog we needed a way to write **multilayer** **PSDs** with **groups** and this library is the result after days of headaches.

It features:

* Multilayer PSD creation
* Grouping of layers
* Unicode layer name support
* Some layer configurations (like the blend mode of the layer)
* ARC (Automatic Reference Counting)

What SFPSDWriter **NOT** features:

* Ability to read PSD files

## Usage

### In two words:

* Create an instance a SFPSDWriter object
* Add how many layers you want
* Eventually modify the layer's characteristics
* Retrieve the NSData generated by the SFPSDWriter and store it wherever you want

### Of course, some code:

#### Mac OS X

```Objective-C
    // The images we want to insert in the PSD
    NSImage *firstImage = [NSImage imageNamed:@"firstImage"];
    NSImage *secondImage = [NSImage imageNamed:@"secondImage"];
    
    // SFPSDWriter instance
    SFPSDWriter *psdWriter = [[SFPSDWriter alloc] initWithDocumentSize:NSSizeToCGSize(firstImage.size) andResolution:300.0 andResolutionUnit:SFPSDResolutionUnitPPI];
    
    // We want all our layers to be included in a group...
    SFPSDGroupOpeningLayer *firstGroup = [psdWriter openGroupLayerWithName:@"We ♥ groups!"];
    
    // ... and the group should be open at file opening
    [firstGroup setIsOpened:YES];
    
    // Adding the first image layer
    [psdWriter addLayerWithCGImage:[[[firstImage representations] objectAtIndex:0] CGImage]
                           andName:@"First Layer"
                        andOpacity:1
                         andOffset:NSMakePoint(0, 0)];
    
    // I mean, we really love groups
    // This time we don't need to change group's attributes so we don't store the reference
    [psdWriter openGroupLayerWithName:@"You'll have to open me!"];
    
    // The second image will be in the second group, offsetted by (116px, 66px), semi-transparent...
    SFPSDLayer *secondLayer = [psdWriter addLayerWithCGImage:[[[secondImage representations] objectAtIndex:0] CGImage]
                                                     andName:@"Second Layer"
                                                  andOpacity:0.5
                                                   andOffset:NSMakePoint(116, 66)];
    
    // ... and with "Darken" blend mode
    [secondLayer setBlendMode:SFPSDLayerBlendModeDarken];
    
    // We have to close every group we've opened
    [psdWriter closeCurrentGroupLayer]; // second group
    [psdWriter closeCurrentGroupLayer]; // first group
    
    // We'll write our test file to the Desktop
    NSString *basePath = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
    NSString *fullFilePath = [basePath stringByAppendingPathComponent:@"SFPSDWriter Test File.psd"];
    
    // Retrieving the PSD data
    NSError *error = nil;
    NSData * psd = [psdWriter createPSDDataWithError:&error];
    
    // Checking for errors
    if (nil != error) {
        NSLog(@"There was an error writing the PSD: %@", [error description]);
        return;
    }
    
    // Writing the data on disk
    [psd writeToFile:fullFilePath atomically:NO];
    
    // Opening the newly created file! :)
    [[NSWorkspace sharedWorkspace] openFile:fullFilePath];
```

#### iOS

```Objective-C
    // The images we want to insert in the PSD
    UIImage *firstImage = [UIImage imageNamed:@"firstImage"];
    UIImage *secondImage = [UIImage imageNamed:@"secondImage"];
    
    // SFPSDWriter instance
    SFPSDWriter *psdWriter = [[SFPSDWriter alloc] initWithDocumentSize:firstImage.size andResolution:300.0 andResolutionUnit:SFPSDResolutionUnitPPI];
    
    // We want all our layers to be included in a group...
    SFPSDGroupOpeningLayer *firstGroup = [psdWriter openGroupLayerWithName:@"We ♥ groups!"];
    
    // ... and the group should be open at file opening
    [firstGroup setIsOpened:YES];
    
    // Adding the first image layer
    [psdWriter addLayerWithCGImage:[firstImage CGImage]
                           andName:@"First Layer"
                        andOpacity:1
                         andOffset:CGPointMake(0, 0)];
    
    // I mean, we really love groups
    // This time we don't need to change group's attributes so we don't store the reference
    [psdWriter openGroupLayerWithName:@"You'll have to open me!"];
    
    // The second image will be in the second group, offsetted by (116px, 66px), semi-transparent...
    SFPSDLayer *secondLayer = [psdWriter addLayerWithCGImage:[secondImage CGImage]
                                                     andName:@"Second Layer"
                                                  andOpacity:0.5
                                                   andOffset:CGPointMake(116, 66)];
    
    // ... and with "Darken" blend mode
    [secondLayer setBlendMode:SFPSDLayerBlendModeDarken];
    
    // We have to close every group we've opened
    [psdWriter closeCurrentGroupLayer]; // second group
    [psdWriter closeCurrentGroupLayer]; // first group
    
    // We'll write our test file into the documents folder of the application
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *fullFilePath = [documentsDirectory stringByAppendingPathComponent:@"SFPSDWriter Test File.psd"];
    
    // Retrieving the PSD data
    NSError *error = nil;
    NSData * psd = [psdWriter createPSDDataWithError:&error];
    
    // Checking for errors
    if (nil != error) {
        NSLog(@"There was an error writing the PSD: %@", [error description]);
        return;
    }
    
    // Writing the data on disk
    // When using the simulator we can find the file in
    // /Users/<Username>/Library/Application\ Support/iPhone\ Simulator/<Simulator Version>/Applications/<Application>/Documents
    [psd writeToFile:fullFilePath atomically:NO];
```

## Example Projects

The example projects are a copy and paste of the code in the [Usage](https://github.com/shinyfrog/SFPSDWriter#usage) section in:

```Objective-C
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification // Mac OS X
```

and

```Objective-C
- (void)applicationDidBecomeActive:(UIApplication *)application // iOS
```

There is also a debug project used to stress test the library. You can find it in *[Example Projects/SFPSDWriter Stress Tester](https://github.com/shinyfrog/SFPSDWriter/tree/master/Example%20Projects/SFPSDWriter%20Stress%20Tester)*.

## Status

The library is functionally complete for our needs so there is no planning on working on it. Obviously there will be bugfixes or speedups if we'll found some while using it.

There is no plan to make this library able to read PSDs. Or let's make it this way: there is a concrete plan to **not** make the library read PSD files.

At this point I'd like to invite you to read this [famous comment](https://code.google.com/p/xee/source/browse/XeePhotoshopLoader.m#108) to let you understand what does it mean to work with PSD files. Have to admit that I found that comment motivational but I'm a pervert. Don't play with PSD files if you can. :)

## Contributing

We will happily evaluate the possibility to accept pull requests so if you have suggestions - you are welcome to let us know.

## Acknowledgments

This library gets inspiration from [Ben Gotow](https://github.com/bengotow)'s [PSDWriter](https://github.com/bengotow/PSDWriter). It was reorganized a bit in the structure to depute the writing of the informations and the channels to the layers (and adding something here and there).

This library would be not possible without some pro tips of [Gus Mueller](https://github.com/ccgus) ([@ccgus](https://twitter.com/ccgus)) about the misterious behaviour of PSD groups!
