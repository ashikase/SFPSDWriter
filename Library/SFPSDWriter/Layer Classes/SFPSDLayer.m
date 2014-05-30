//
//  SFPSDLayer.m
//  SFPSDWriter
//
//  Created by Konstantin Erokhin on 06/06/13.
//  Copyright (c) 2013 Shiny Frog. All rights reserved.
//
//  Inspired by PSDWriter by Ben Gotow ( https://github.com/bengotow/PSDWriter )
//

#import <malloc/malloc.h>

#import "SFPSDLayer.h"

#import "NSMutableData+SFAppendValue.h"
#import "NSData+SFPackedBits.h"
#import "NSString+SFPascalString.h"

@implementation SFPSDLayer {
    CGImageRef _croppedImage;
}

@synthesize image = _image, name = _name, opacity = _opacity, offset = _offset, documentSize = _documentSize, numberOfChannels = _numberOfChannels;
@synthesize shouldFlipLayerData = _shouldFlipLayerData, shouldUnpremultiplyLayerData = _shouldUnpremultiplyLayerData;

#pragma mark - Init and dealloc

- (id)init
{
    return [self initWithNumberOfChannels:4 andOpacity:1.0 andShouldFlipLayerData:NO andShouldUnpremultiplyLayerData:NO andBlendMode:SFPSDLayerBlendModeNormal];
}

- (id)initWithNumberOfChannels:(int)numberOfChannels andOpacity:(float)opacity andShouldFlipLayerData:(BOOL)shouldFlipLayerData andShouldUnpremultiplyLayerData:(BOOL)shouldUnpremultiplyLayerData andBlendMode:(NSString *)blendMode
{
    self = [super init];
    if (!self) return nil;
    
    self.numberOfChannels = numberOfChannels;
    self.opacity = opacity;
    self.shouldFlipLayerData = shouldFlipLayerData;
    self.shouldUnpremultiplyLayerData = shouldUnpremultiplyLayerData;
    self.blendMode = blendMode;
    
    return self;
}

- (void)dealloc
{
    self.blendMode = nil;
    self.visibleImageData = nil;
    self.name = nil;
    
    if (_image != nil) {
        CGImageRelease(_image);
        _image = nil;
    }

    if (_croppedImage != NULL) {
        CGImageRelease(_croppedImage);
        _croppedImage = NULL;
    }
}

#pragma mark - Setters

- (void)setImage:(CGImageRef)image
{
    // The image is the same
    if (image == _image) {
        return;
    }
    
    // If the image was previously assigned - it is surely a copy and we have to clean it
    if (_image != nil) {
        CGImageRelease(_image);
        _image = nil;
    }
    
    // Assigning
    CGImageRef imageCopy = nil;
    if (image != nil) {
        imageCopy = CGImageCreateCopy(image);
    }
    _image = imageCopy;
    
    // The previously cached imageData is invalid
    [self setVisibleImageData:nil];
}

- (void)setDocumentSize:(CGSize)documentSize
{
    if (_documentSize.width != documentSize.width && _documentSize.height != documentSize.height) {
        _documentSize = documentSize;
    }
    
    // The previously cached imageData is invalid
    [self setVisibleImageData:nil];
}

#pragma mark - Getters

- (NSData *)visibleImageData
{
    if (_visibleImageData == nil) {
        _visibleImageData = CGImageGetData([self croppedImage], [self imageCropRegion]);
    }
    return _visibleImageData;
}

- (CGImageRef)croppedImage
{
    if (_croppedImage == NULL) {
        _croppedImage = CGImageCreateWithImageInRect([self image], [self imageCropRegion]);
    }
    return _croppedImage;
}

#pragma mark - Size retrieving functions

- (BOOL)hasValidSize
{
    CGRect imageCropRegion = [self imageCropRegion];

    // The only test we need to perform to know if the image is inside the document's bounds
    if (imageCropRegion.size.width <= 0 || imageCropRegion.size.height <= 0) {
        return NO;
    }
    
    return YES;
}

- (CGRect)imageCropRegion
{
    CGRect imageCropRegion = CGRectMake(0, 0, CGImageGetWidth(self.image), CGImageGetHeight(self.image));
    
    CGRect imageInDocumentRegion = CGRectMake(self.offset.x, self.offset.y, imageCropRegion.size.width, imageCropRegion.size.height);

    if (imageInDocumentRegion.origin.x < 0) {
        imageCropRegion.size.width = imageCropRegion.size.width + imageInDocumentRegion.origin.x;
        imageCropRegion.origin.x = abs(imageInDocumentRegion.origin.x);
    }
    if (imageInDocumentRegion.origin.y < 0) {
        imageCropRegion.size.height = imageCropRegion.size.height + imageInDocumentRegion.origin.y;
        imageCropRegion.origin.y = abs(imageInDocumentRegion.origin.y);
    }
    
    if (imageInDocumentRegion.origin.x + imageInDocumentRegion.size.width > self.documentSize.width) {
        imageCropRegion.size.width = self.documentSize.width - imageInDocumentRegion.origin.x;
    }
    if (imageInDocumentRegion.origin.y + imageInDocumentRegion.size.height > self.documentSize.height) {
        imageCropRegion.size.height = self.documentSize.height - imageInDocumentRegion.origin.y;
    }

    return  imageCropRegion;
}

- (CGRect)imageInDocumentRegion
{
    CGRect imageCropRegion = [self imageCropRegion];
    CGRect imageInDocumentRegion = CGRectMake(self.offset.x, self.offset.y, imageCropRegion.size.width, imageCropRegion.size.height);
    
    // The layer's image cannot have the origin below the 0...
    imageInDocumentRegion.origin.x = MAX(imageInDocumentRegion.origin.x, 0);
    imageInDocumentRegion.origin.y = MAX(imageInDocumentRegion.origin.y, 0);
    
    // ... and higher of the document bounds
    imageInDocumentRegion.origin.x = MIN(imageInDocumentRegion.origin.x, [self documentSize].width);
    imageInDocumentRegion.origin.y = MIN(imageInDocumentRegion.origin.y, [self documentSize].height);
    
    return imageInDocumentRegion;
}

#pragma mark - Public writing functions

- (void)writeLayerInformationOn:(NSMutableData *)layerInformation
{
    // print out top left bottom right 4x4
    CGRect rect;
    if (self.shouldCrop) {
        rect = [self imageInDocumentRegion];
    } else {
        rect = (CGRect){CGPointZero, self.documentSize};
    }
    [layerInformation sfAppendValue:rect.origin.y length:4];
    [layerInformation sfAppendValue:rect.origin.x length:4];
    [layerInformation sfAppendValue:rect.origin.y + rect.size.height length:4];
    [layerInformation sfAppendValue:rect.origin.x + rect.size.width length:4];

    // print out number of channels in the layer
    [layerInformation sfAppendValue:[self numberOfChannels] length:2];
    
    // ARC in this case not cleans the memory used for layerChannels even after the SFPSDWriter is cleared.
    // With an autoreleasepool we force the clean of the memory.
    @autoreleasepool {
        NSArray *layerChannels = [self layerChannels];
        
        // print out data about each channel of the RGB
        for (int i = 0; i < 3; i++) {
            [layerInformation sfAppendValue:i length:2];
            NSUInteger channelInformationLength = [[layerChannels objectAtIndex:i] length];
            [layerInformation sfAppendValue:channelInformationLength length:4];
        }
        
        // If the alpha channel exists
        if ([self numberOfChannels] > 3) {
            // The alpha channel is number -1
            Byte b[2] = {0xFF, 0xFF};
            [layerInformation appendBytes:&b length:2];
            NSUInteger channelInformationLength = [[layerChannels objectAtIndex:3] length];
            [layerInformation sfAppendValue:channelInformationLength length:4];
        }
        
    } // autoreleasepool

    // print out blend mode
    [layerInformation sfAppendUTF8String:@"8BIM" length:4];
    [layerInformation sfAppendUTF8String:[self blendMode] length:4];
    
    // print out opacity
    int opacity = ceilf(self.opacity * 255.0f);
    [layerInformation sfAppendValue:opacity length:1];
    
    // print out clipping
    [layerInformation sfAppendValue:0 length:1]; // 0 = base, 1 = non-base
    
    // print out flags.
    // bit 0 = transparency protected;
    // bit 1 = visible;
    // bit 2 = obsolete;
    // bit 3 = 1 for Photoshop 5.0 and later, tells if bit 4 has useful information;
    // bit 4 = pixel data irrelevant to appearance of document
    [layerInformation sfAppendValue:0 length:1];
    
    // print out filler
    [layerInformation sfAppendValue:0 length:1];
    
    // Overrided in special layers
    NSData *extraData = [self extraLayerInformation];
    
    // print out extra data length
    [layerInformation sfAppendValue:[extraData length] length:4];
    // print out extra data
    [layerInformation appendData:extraData];
}

- (void)writeLayerChannelsOn:(NSMutableData *)layerInformation
{
    // ARC in this case not cleans the memory used for layerChannels even after the SFPSDWriter is cleared.
    // With an autoreleasepool we force the clean of the memory.
    @autoreleasepool {
        NSArray *layerChannels = [self layerChannels];
        for (int i = 0; i < [layerChannels count]; i++) {
            [layerInformation appendData:[layerChannels objectAtIndex:i]];
        }
    } // autoreleasepool
}

#pragma mark - Protecred functions [should never be used from outside the class]

- (NSArray *)layerChannels
{
    NSMutableArray *channels = [NSMutableArray array];

    CGRect bounds = [self imageInDocumentRegion];
    bounds.origin.x = floorf(bounds.origin.x);
    bounds.origin.y = floorf(bounds.origin.y);
    bounds.size.width = floorf(bounds.size.width);
    bounds.size.height = floorf(bounds.size.height);

    int imageRowBytes = bounds.size.width * 4;

    if (self.shouldCrop) {
        for (int channel = 0; channel < [self numberOfChannels]; channel++)
        {
            NSMutableData *byteCounts = [[NSMutableData alloc] initWithCapacity:bounds.size.height * self.numberOfChannels * 2];
            NSMutableData *scanlines = [[NSMutableData alloc] init];

            for (int row = 0; row < bounds.size.height; row++)
            {
                int byteCount = 0;

                // Appending the layer's image row
                NSRange packRange = NSMakeRange(row * imageRowBytes + channel, imageRowBytes);
                NSData *packed = [[self visibleImageData] sfPackedBitsForRange:packRange skip:4];
                [scanlines appendData:packed];
                byteCount += [packed length];

                [byteCounts sfAppendValue:byteCount length:2];
                
                packed = nil;
            }
            
            NSMutableData *channelData = [[NSMutableData alloc] init];
            // write channel compression format
            [channelData sfAppendValue:1 length:2];
            
            // write channel byte counts
            [channelData appendData:byteCounts];
            // write channel scanlines
            [channelData appendData:scanlines];
            
            // add completed channel data to channels array
            [channels addObject:channelData];

            byteCounts = scanlines = nil;
        }
    } else {
        // This is for later when we write the transparent top and bottom of the shape
        int transparentRowSize = sizeof(Byte) * (int)ceilf(self.documentSize.width * 4);
        Byte *transparentRow = malloc(transparentRowSize);
        
        if ([self numberOfChannels] > 3) {
            memset(transparentRow, 0, transparentRowSize);
        } else {
            memset(transparentRow, 255, transparentRowSize); // 255 because we want the not transparent layer be white (0 - will be black)
        }
        
        NSData *transparentRowData = [NSData dataWithBytesNoCopy:transparentRow length:transparentRowSize freeWhenDone:NO];
        NSData *packedTransparentRowData = [transparentRowData sfPackedBitsForRange:NSMakeRange(0, transparentRowSize) skip:4];
    
        NSRange leftPackRange = NSMakeRange(0, (int)bounds.origin.x * 4);
        NSData *packedLeftOfShape = [transparentRowData sfPackedBitsForRange:leftPackRange skip:4];
        NSRange rightPackRange = NSMakeRange(0, (int)(self.documentSize.width - bounds.origin.x - bounds.size.width) * 4);
        NSData *packedRightOfShape = [transparentRowData sfPackedBitsForRange:rightPackRange skip:4];
    
        for (int channel = 0; channel < [self numberOfChannels]; channel++)
        {
            NSMutableData *byteCounts = [[NSMutableData alloc] initWithCapacity:self.documentSize.height * self.numberOfChannels * 2];
            NSMutableData *scanlines = [[NSMutableData alloc] init];

            for (int row = 0; row < self.documentSize.height; row++)
            {
                // If it's above or below the shape's bounds, just write black with 0-alpha
                if (row < (int)bounds.origin.y || row >= (int)(bounds.origin.y + bounds.size.height)) {
                    [byteCounts sfAppendValue:[packedTransparentRowData length] length:2];
                    [scanlines appendData:packedTransparentRowData];
                } else {
                    int byteCount = 0;

                    // Appending the transparent space before the shape
                    if (bounds.origin.x > 0.01) {
                        // Append the transparent portion to the left of the shape
                        [scanlines appendData:packedLeftOfShape];
                        byteCount += [packedLeftOfShape length];
                    }
                    
                    // Appending the layer's image row
                    NSRange packRange = NSMakeRange((row - (int)bounds.origin.y) * imageRowBytes + channel, imageRowBytes);
                    NSData *packed = [[self visibleImageData] sfPackedBitsForRange:packRange skip:4];
                    [scanlines appendData:packed];
                    byteCount += [packed length];

                    // Appending the transparent space after the shape
                    if (bounds.origin.x + bounds.size.width < self.documentSize.width) {
                        // Append the transparent portion to the right of the shape
                        [scanlines appendData:packedRightOfShape];
                        byteCount += [packedRightOfShape length];
                    }
                    
                    [byteCounts sfAppendValue:byteCount length:2];
                    
                    packed = nil;
                }
            }
            
            NSMutableData *channelData = [[NSMutableData alloc] init];
            // write channel compression format
            [channelData sfAppendValue:1 length:2];
            
            // write channel byte counts
            [channelData appendData:byteCounts];
            // write channel scanlines
            [channelData appendData:scanlines];
            
            // add completed channel data to channels array
            [channels addObject:channelData];

            byteCounts = scanlines = nil;
        }

        packedLeftOfShape = packedRightOfShape = nil;
        transparentRowData = packedTransparentRowData = nil;
        
        free(transparentRow);
    }

    return channels;
}

- (void)writeNameOn:(NSMutableData *)data withPadding:(int)padding
{
    NSString *layerName = [self.name stringByAppendingString:@" "]; // The white space is there to simulate the space reserved by the leading length
    const char *pascalName = [layerName sfPascalStringPaddedTo:4];
    int pascalNameLength = [layerName sfPascalStringLengthPaddedTo:4];
    [data sfAppendValue:[self.name length] length:1];
    [data appendBytes:pascalName length:pascalNameLength - 1]; // -1 because it was the space reserved for writing the heading length of the string
}

- (void)writeUnicodeNameOn:(NSMutableData *)data
{
    [data sfAppendUTF8String:@"8BIM" length:4];
    [data sfAppendUTF8String:@"luni" length:4]; // Unicode layer name (Photoshop 5.0)
    
    NSRange r = NSMakeRange(0, [self.name length]);
    
    [data sfAppendValue:(r.length * 2) + 4 length:4]; // length of the next bit of data
    [data sfAppendValue:r.length length:4]; // length of the unicode string data
    
    int bufferSize = sizeof(unichar) * ((int)[self.name length] + 1);
    unichar *buffer = malloc(bufferSize);
    [self.name getCharacters:buffer range:r];
    buffer[([self.name length])] = 0;
    for (NSUInteger i = 0; i < [self.name length]; i++) {
        [data sfAppendValue:buffer[i] length:2];
    }
    free(buffer);
}

- (NSData *)extraLayerInformation
{
    // new stream of data for the extra information
    NSMutableData *extraDataStream = [[NSMutableData alloc] init];
    
    [extraDataStream sfAppendValue:0 length:4]; // Layer mask / adjustment layer data. Size of the data: 36, 20, or 0.
    [extraDataStream sfAppendValue:0 length:4]; // Layer blending ranges data. Length of layer blending ranges data
    
    // Layer name: Pascal string, padded to a multiple of 4 bytes.
    [self writeNameOn:extraDataStream withPadding:4];
    
    // Unicode layer name (Photoshop 5.0). Unicode string (4 bytes length + string).
    [self writeUnicodeNameOn:extraDataStream];
    
    return extraDataStream;
}

#pragma mark - Class description

-(NSString *)description
{
    return [NSString stringWithFormat:@"(super: %@): Layer named '%@' (opacity: %f). Image Crop Region: (%f, %f, %f, %f). Image In Document Region (%f, %f, %f, %f)",
            [super description],
            self.name,
            self.opacity,
            self.imageCropRegion.origin.x,
            self.imageCropRegion.origin.y,
            self.imageCropRegion.size.width,
            self.imageCropRegion.size.height,
            self.imageInDocumentRegion.origin.x,
            self.imageInDocumentRegion.origin.y,
            self.imageInDocumentRegion.size.width,
            self.imageInDocumentRegion.size.height];
}

@end

#pragma mark - Convenience functions

NSData *CGImageGetData(CGImageRef image, CGRect region)
{
	// Create the bitmap context
	CGContextRef	context = NULL;
	void *			bitmapData;
	int				bitmapByteCount;
	int				bitmapBytesPerRow;
	
	// Get image width, height. We'll use the entire image.
	int width = region.size.width;
	int height = region.size.height;
	
	// Declare the number of bytes per row. Each pixel in the bitmap in this
	// example is represented by 4 bytes; 8 bits each of red, green, blue, and
	// alpha.
	bitmapBytesPerRow = (width * 4);
	bitmapByteCount	= (bitmapBytesPerRow * height);
	
	// Allocate memory for image data. This is the destination in memory
	// where any drawing to the bitmap context will be rendered.
	//	bitmapData = malloc(bitmapByteCount);
	bitmapData = calloc(width * height * 4, sizeof(Byte));
	if (bitmapData == NULL)
	{
		return nil;
	}
	
	// Create the bitmap context. We want pre-multiplied ARGB, 8-bits
	// per component. Regardless of what the source image format is
	// (CMYK, Grayscale, and so on) it will be converted over to the format
	// specified here by CGBitmapContextCreate.
	//	CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
	CGColorSpaceRef colorspace = CGImageGetColorSpace(image);
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaPremultipliedLast; // In order to suppress the warning (http://stackoverflow.com/a/18921840)
	context = CGBitmapContextCreate(bitmapData, width, height, 8, bitmapBytesPerRow,
									colorspace, bitmapInfo);
	//	CGColorSpaceRelease(colorspace);
	
	if (context == NULL)
		// error creating context
		return nil;
	
	// Draw the image to the bitmap context. Once we draw, the memory
	// allocated for the context for rendering will then contain the
	// raw image data in the specified color space.
	CGContextSaveGState(context);
	
	// Draw the image without scaling it to fit the region
	CGRect drawRegion;
	drawRegion.origin = CGPointZero;
	drawRegion.size.width = width;
	drawRegion.size.height = height;
	CGContextTranslateCTM(context,
						  -region.origin.x + (drawRegion.size.width - region.size.width),
						  -region.origin.y - (drawRegion.size.height - region.size.height));
	CGContextDrawImage(context, region, image);
	CGContextRestoreGState(context);
	
	// When finished, release the context
	CGContextRelease(context);
	
	// Now we can get a pointer to the image data associated with the bitmap context.
	
	NSData *data = [NSData dataWithBytes:bitmapData length:bitmapByteCount];
	free(bitmapData);
	
	return data;
}

