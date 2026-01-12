#include "quakedef.h"
#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/QuartzCore.h>

// From d_local.h - extern what we need
extern short *d_pzbuffer;
void D_InitCaches(void *buffer, int size);

// Globals
viddef_t vid;
unsigned short d_8to16table[256];
unsigned d_8to24table[256];
void (*vid_menudrawfn)(void);
void (*vid_menukeyfn)(int key);

// Software renderer buffers
static short zbuffer[640 * 480];
static byte surfcache[512 * 1024]; // 512KB surface cache

// Metal Globals
id<MTLDevice> device;
id<MTLCommandQueue> commandQueue;
id<MTLRenderPipelineState> pipelineState;

// Triple buffering variables
#define MaxFramesInFlight 3
dispatch_semaphore_t inflight_semaphore;
id<MTLTexture> indexTextures[MaxFramesInFlight]; // R8Uint textures
NSUInteger currentFrameIndex = 0;

// Palette texture
id<MTLTexture> paletteTexture; // RGBA8Unorm 256x1 texture

MTKView *view;
NSWindow *window;

// Shader Source implementation (embedded)
NSString *const kMetalShaderSource =
    @"\n"
     "#include <metal_stdlib>\n"
     "using namespace metal;\n"
     "\n"
     "struct VertexOut {\n"
     "    float4 position [[position]];\n"
     "    float2 texCoord;\n"
     "};\n"
     "\n"
     "vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {\n"
     "    VertexOut out;\n"
     "    // Full-screen quad\n"
     "    float2 positions[4] = { float2(-1, -1), float2(1, -1), float2(-1, "
     "1), float2(1, 1) };\n"
     "    float2 texCoords[4] = { float2(0, 1), float2(1, 1), float2(0, 0), "
     "float2(1, 0) };\n"
     "    \n"
     "    out.position = float4(positions[vertexID], 0.0, 1.0);\n"
     "    out.texCoord = texCoords[vertexID];\n"
     "    return out;\n"
     "}\n"
     "\n"
     "fragment float4 fragmentShader(VertexOut in [[stage_in]],\n"
     "                               texture2d<uint> indexTexture "
     "[[texture(0)]],\n"
     "                               texture2d<float> paletteTexture "
     "[[texture(1)]])\n"
     "{\n"
     "    constexpr sampler s(mag_filter::nearest, min_filter::nearest);\n"
     "    // Sample the 8-bit index (0-255)\n"
     "    uint index = indexTexture.sample(s, in.texCoord).r;\n"
     "    \n"
     "    // Look up the color in the palette texture (256x1)\n"
     "    // We read directly using pixel coordinates for precision\n"
     "    float4 color = paletteTexture.read(uint2(index, 0));\n"
     "    return color;\n"
     "}\n";

@interface QuakeMTKView : MTKView
@end

@implementation QuakeMTKView
- (BOOL)acceptsFirstResponder {
  return YES;
}
- (BOOL)canBecomeKeyView {
  return YES;
}
@end

@interface QuakeRenderer : NSObject <MTKViewDelegate>
@end

@implementation QuakeRenderer
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
}
- (void)drawInMTKView:(nonnull MTKView *)view {
}
@end

QuakeRenderer *renderer;

// Helper to build pipeline
void BuildPipeline(void) {
  NSError *error = nil;
  id<MTLLibrary> library = [device newLibraryWithSource:kMetalShaderSource
                                                options:nil
                                                  error:&error];
  if (!library) {
    Sys_Error("Pipeline Error: %s", [[error localizedDescription] UTF8String]);
  }

  MTLRenderPipelineDescriptor *pipelineDescriptor =
      [[MTLRenderPipelineDescriptor alloc] init];
  pipelineDescriptor.label = @"QuakePipeline";
  pipelineDescriptor.vertexFunction =
      [library newFunctionWithName:@"vertexShader"];
  pipelineDescriptor.fragmentFunction =
      [library newFunctionWithName:@"fragmentShader"];
  pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

  pipelineState =
      [device newRenderPipelineStateWithDescriptor:pipelineDescriptor
                                             error:&error];
  if (!pipelineState) {
    Sys_Error("Pipeline State Error: %s",
              [[error localizedDescription] UTF8String]);
  }
}

// Update palette texture from Quake's raw RGB palette
void UpdatePaletteLUT(unsigned char *palette) {
  if (!palette || !paletteTexture)
    return;

  uint32_t temp_palette[256];
  for (int i = 0; i < 256; i++) {
    unsigned char r = palette[i * 3];
    unsigned char g = palette[i * 3 + 1];
    unsigned char b = palette[i * 3 + 2];
    // Metal generic storage A B G R (little endian) -> R G B A in shader with
    // float read? Wait. R8 Uint -> R is index. Palette Texture is RGBA8Unorm.
    // Bytes passed to replaceRegion are expected to follow pixel format.
    // If format is RGBA8Unorm, data should be R, G, B, A in byte order.
    // For Little Endian u32: A B G R.
    // (A << 24) | (B << 16) | (G << 8) | R
    // We want opaque alpha.
    temp_palette[i] = (255 << 24) | (b << 16) | (g << 8) | r;
  }

  [paletteTexture replaceRegion:MTLRegionMake2D(0, 0, 256, 1)
                    mipmapLevel:0
                      withBytes:temp_palette
                    bytesPerRow:256 * 4];
}

void VID_Init(unsigned char *palette) {
  printf("VID_Init: Initializing Metal Backend (Optimized)...\n");

  vid.width = 640;
  vid.height = 480;
  vid.rowbytes = vid.width;
  vid.buffer = malloc(vid.width * vid.height);
  vid.conwidth = vid.width;
  vid.conheight = vid.height;
  vid.conrowbytes = vid.rowbytes;
  vid.conbuffer = vid.buffer;
  vid.aspect = ((float)vid.width / (float)vid.height);
  vid.numpages = 1;
  vid.colormap = host_colormap;
  vid.fullbright = 256 - LittleLong(*((int *)vid.colormap + 2048));

  // Initialize software renderer buffers
  d_pzbuffer = zbuffer;
  D_InitCaches(surfcache, sizeof(surfcache));

  // Metal Setup
  device = MTLCreateSystemDefaultDevice();
  if (!device)
    Sys_Error("VID_Init: No Metal Device");
  commandQueue = [device newCommandQueue];

  inflight_semaphore = dispatch_semaphore_create(MaxFramesInFlight);

  // Build Pipeline
  BuildPipeline();

  // Window Setup
  NSRect frame = NSMakeRect(0, 0, vid.width, vid.height);
  NSUInteger styleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                         NSWindowStyleMaskMiniaturizable |
                         NSWindowStyleMaskResizable;
  window = [[NSWindow alloc] initWithContentRect:frame
                                       styleMask:styleMask
                                         backing:NSBackingStoreBuffered
                                           defer:NO];
  [window setTitle:@"Quake (Metal Optimized)"];

  view = [[QuakeMTKView alloc] initWithFrame:frame device:device];
  view.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
  view.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
  view.paused = YES;                  // we control the loop
  view.enableSetNeedsDisplay = NO;    // we don't use setNeedsDisplay
  view.preferredFramesPerSecond = 60; // Hints logical display update
  renderer = [[QuakeRenderer alloc] init];
  view.delegate = renderer;
  [window setContentView:view];
  [window makeKeyAndOrderFront:nil];
  [window center];

  // Ensure window and view can receive keyboard input
  [NSApp activateIgnoringOtherApps:YES];
  [window makeFirstResponder:view];

  // Register window with sys_macos for close detection
  extern void Sys_RegisterWindow(NSWindow *);
  Sys_RegisterWindow(window);

  // 1. Index Textures Setup (Triple Buffered)
  MTLTextureDescriptor *idxDesc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Uint
                                   width:vid.width
                                  height:vid.height
                               mipmapped:NO];
  idxDesc.usage = MTLTextureUsageShaderRead;
  // Use Shared storage for frequent CPU updates on Apple Silicon
  idxDesc.storageMode = MTLStorageModeShared;

  for (int i = 0; i < MaxFramesInFlight; i++) {
    indexTextures[i] = [device newTextureWithDescriptor:idxDesc];
  }

  // 2. Palette Texture Setup
  MTLTextureDescriptor *palDesc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                   width:256
                                  height:1
                               mipmapped:NO];
  palDesc.usage = MTLTextureUsageShaderRead;
  paletteTexture = [device newTextureWithDescriptor:palDesc];

  // Initial Palette
  UpdatePaletteLUT(palette);

  printf("VID_Init: Metal Initialized Successfully.\n");
}

void VID_Shutdown(void) {
  if (vid.buffer)
    free(vid.buffer);
}

void VID_Update(vrect_t *rects) {
  // Wait for available buffer
  dispatch_semaphore_wait(inflight_semaphore, DISPATCH_TIME_FOREVER);

  // Cycle to next texture
  currentFrameIndex = (currentFrameIndex + 1) % MaxFramesInFlight;
  id<MTLTexture> currentTexture = indexTextures[currentFrameIndex];

  // 1. Upload 8-bit buffer directly to GPU
  // Optimization: Only upload the modified region? No, software renderer
  // updates mostly everything. Full upload is cheap for 640x480 R8 (300KB).
  [currentTexture replaceRegion:MTLRegionMake2D(0, 0, vid.width, vid.height)
                    mipmapLevel:0
                      withBytes:vid.buffer
                    bytesPerRow:vid.width];

  // 2. Render
  @autoreleasepool {
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];

    // Signal semaphore when GPU is done with this frame
    __block dispatch_semaphore_t sem = inflight_semaphore;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
      dispatch_semaphore_signal(sem);
    }];

    MTLRenderPassDescriptor *passDescriptor = view.currentRenderPassDescriptor;

    if (passDescriptor != nil) {
      id<MTLRenderCommandEncoder> renderEncoder =
          [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
      [renderEncoder setRenderPipelineState:pipelineState];

      // Bind Index Texture (0) and Palette Texture (1)
      [renderEncoder setFragmentTexture:currentTexture atIndex:0];
      [renderEncoder setFragmentTexture:paletteTexture atIndex:1];

      [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip
                        vertexStart:0
                        vertexCount:4];
      [renderEncoder endEncoding];
      [commandBuffer presentDrawable:view.currentDrawable];
    } else {
      // If we can't draw (minimized?), ensure we signal semaphore or we
      // deadlock Actually addCompletedHandler runs even if we don't present?
      // Yes, commit triggers it. But if passDescriptor is nil, we typically
      // don't commit empty work? We MUST commit to trigger handler.
    }

    [commandBuffer commit];
  }
}

int VID_SetMode(int modenum, unsigned char *palette) { return 1; }

void VID_SetPalette(unsigned char *palette) { UpdatePaletteLUT(palette); }

void VID_ShiftPalette(unsigned char *palette) { VID_SetPalette(palette); }

void VID_HandlePause(qboolean pause) {}

void D_BeginDirectRect(int x, int y, byte *pbitmap, int width, int height) {}
void D_EndDirectRect(int x, int y, int width, int height) {}
