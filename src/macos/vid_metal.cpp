#define NS_PRIVATE_IMPLEMENTATION
#define CA_PRIVATE_IMPLEMENTATION
#define MTL_PRIVATE_IMPLEMENTATION

// Quake includes
extern "C" {
    #define __QBOOLEAN_DEFINED__
    typedef int qboolean;
    #define true 1
    #define false 0
    #include "quakedef.h"
    #undef true
    #undef false
    void M_Menu_Options_f(void);
}

#include <Foundation/Foundation.hpp>
#include <Metal/Metal.hpp>
#include <QuartzCore/QuartzCore.hpp>
#include <objc/runtime.h>
#include <objc/message.h>
#include <stdlib.h>
#include <vector>
#include <string>
#include <fstream>

#include "vid_metal.hpp"
#include "Metal_Settings.h"

// GCD parallel dispatch (from GCD_Tasks.m)
extern "C" void MQ_ParallelFor(size_t count, size_t stride,
                                void* queue,
                                void (^block)(size_t index));

// CoreML neural pipeline (from MQ_CoreML.m)
extern "C" int MQ_CoreML_Denoise(void* input, void* output, int width, int height);
extern "C" int MQ_CoreML_UpscaleTexture(const unsigned char* inputPixels, unsigned char* outputPixels, int inW, int inH);

// ---------------------------------------------------------------------------
// Quake Globals
// ---------------------------------------------------------------------------
extern "C" {
    viddef_t vid;
    unsigned short d_8to16table[256];
    unsigned d_8to24table[256];
    void (*vid_menudrawfn)(void) = nullptr;
    void (*vid_menukeyfn)(int key) = nullptr;
    qboolean r_cache_thrash = 0;
    int d_con_indirect = 0;
    extern short *d_pzbuffer;
    extern unsigned int d_zrowbytes;
    extern unsigned int d_zwidth;
    void D_InitCaches(void *buffer, int size);
    void Sys_RegisterWindow(void *window);
}

static dispatch_semaphore_t _frameSemaphore;

namespace MetalFX {
    class SpatialScaler : public NS::Object {
    public:
        void setColorTexture(MTL::Texture* texture) { ((void (*)(id, SEL, id))objc_msgSend)((id)this, sel_registerName("setColorTexture:"), (id)texture); }
        void setOutputTexture(MTL::Texture* texture) { ((void (*)(id, SEL, id))objc_msgSend)((id)this, sel_registerName("setOutputTexture:"), (id)texture); }
        void encodeToCommandBuffer(MTL::CommandBuffer* commandBuffer) { ((void (*)(id, SEL, id))objc_msgSend)((id)this, sel_registerName("encodeToCommandBuffer:"), (id)commandBuffer); }
    };
    class SpatialScalerDescriptor : public NS::Object {
    public:
        static SpatialScalerDescriptor* alloc() { return (SpatialScalerDescriptor*)NS::Object::alloc<SpatialScalerDescriptor>("MTLFXSpatialScalerDescriptor"); }
        SpatialScalerDescriptor* init() { return (SpatialScalerDescriptor*)NS::Object::sendMessage<id>(this, sel_registerName("init")); }
        void setInputWidth(NS::UInteger width) { ((void (*)(id, SEL, NS::UInteger))objc_msgSend)((id)this, sel_registerName("setInputWidth:"), width); }
        void setInputHeight(NS::UInteger height) { ((void (*)(id, SEL, NS::UInteger))objc_msgSend)((id)this, sel_registerName("setInputHeight:"), height); }
        void setOutputWidth(NS::UInteger width) { ((void (*)(id, SEL, NS::UInteger))objc_msgSend)((id)this, sel_registerName("setOutputWidth:"), width); }
        void setOutputHeight(NS::UInteger height) { ((void (*)(id, SEL, NS::UInteger))objc_msgSend)((id)this, sel_registerName("setOutputHeight:"), height); }
        void setColorFormat(MTL::PixelFormat format) { ((void (*)(id, SEL, MTL::PixelFormat))objc_msgSend)((id)this, sel_registerName("setColorTextureFormat:"), format); }
        void setOutputFormat(MTL::PixelFormat format) { ((void (*)(id, SEL, MTL::PixelFormat))objc_msgSend)((id)this, sel_registerName("setOutputTextureFormat:"), format); }
        void setColorProcessingMode(int mode) { ((void (*)(id, SEL, int))objc_msgSend)((id)this, sel_registerName("setColorProcessingMode:"), mode); }
        SpatialScaler* newSpatialScaler(MTL::Device* device) { return (SpatialScaler*)NS::Object::sendMessage<id>(this, sel_registerName("newSpatialScalerWithDevice:"), (id)device); }
    };
    // MetalFX Temporal Scaler — uses motion vectors + depth for frame interpolation
    class TemporalScaler : public NS::Object {
    public:
        void setColorTexture(MTL::Texture* t) { ((void (*)(id, SEL, id))objc_msgSend)((id)this, sel_registerName("setColorTexture:"), (id)t); }
        void setDepthTexture(MTL::Texture* t) { ((void (*)(id, SEL, id))objc_msgSend)((id)this, sel_registerName("setDepthTexture:"), (id)t); }
        void setMotionTexture(MTL::Texture* t) { ((void (*)(id, SEL, id))objc_msgSend)((id)this, sel_registerName("setMotionTexture:"), (id)t); }
        void setOutputTexture(MTL::Texture* t) { ((void (*)(id, SEL, id))objc_msgSend)((id)this, sel_registerName("setOutputTexture:"), (id)t); }
        void setInputContentWidth(NS::UInteger w) { ((void (*)(id, SEL, NS::UInteger))objc_msgSend)((id)this, sel_registerName("setInputContentWidth:"), w); }
        void setInputContentHeight(NS::UInteger h) { ((void (*)(id, SEL, NS::UInteger))objc_msgSend)((id)this, sel_registerName("setInputContentHeight:"), h); }
        void setJitterOffsetX(float x) { ((void (*)(id, SEL, float))objc_msgSend)((id)this, sel_registerName("setJitterOffsetX:"), x); }
        void setJitterOffsetY(float y) { ((void (*)(id, SEL, float))objc_msgSend)((id)this, sel_registerName("setJitterOffsetY:"), y); }
        void setReset(bool r) { ((void (*)(id, SEL, BOOL))objc_msgSend)((id)this, sel_registerName("setReset:"), r ? YES : NO); }
        void encodeToCommandBuffer(MTL::CommandBuffer* cb) { ((void (*)(id, SEL, id))objc_msgSend)((id)this, sel_registerName("encodeToCommandBuffer:"), (id)cb); }
    };
    class TemporalScalerDescriptor : public NS::Object {
    public:
        static TemporalScalerDescriptor* alloc() { return (TemporalScalerDescriptor*)NS::Object::alloc<TemporalScalerDescriptor>("MTLFXTemporalScalerDescriptor"); }
        TemporalScalerDescriptor* init() { return (TemporalScalerDescriptor*)NS::Object::sendMessage<id>(this, sel_registerName("init")); }
        void setInputWidth(NS::UInteger w) { ((void (*)(id, SEL, NS::UInteger))objc_msgSend)((id)this, sel_registerName("setInputWidth:"), w); }
        void setInputHeight(NS::UInteger h) { ((void (*)(id, SEL, NS::UInteger))objc_msgSend)((id)this, sel_registerName("setInputHeight:"), h); }
        void setOutputWidth(NS::UInteger w) { ((void (*)(id, SEL, NS::UInteger))objc_msgSend)((id)this, sel_registerName("setOutputWidth:"), w); }
        void setOutputHeight(NS::UInteger h) { ((void (*)(id, SEL, NS::UInteger))objc_msgSend)((id)this, sel_registerName("setOutputHeight:"), h); }
        void setColorFormat(MTL::PixelFormat f) { ((void (*)(id, SEL, MTL::PixelFormat))objc_msgSend)((id)this, sel_registerName("setColorTextureFormat:"), f); }
        void setDepthFormat(MTL::PixelFormat f) { ((void (*)(id, SEL, MTL::PixelFormat))objc_msgSend)((id)this, sel_registerName("setDepthTextureFormat:"), f); }
        void setMotionFormat(MTL::PixelFormat f) { ((void (*)(id, SEL, MTL::PixelFormat))objc_msgSend)((id)this, sel_registerName("setMotionTextureFormat:"), f); }
        void setOutputFormat(MTL::PixelFormat f) { ((void (*)(id, SEL, MTL::PixelFormat))objc_msgSend)((id)this, sel_registerName("setOutputTextureFormat:"), f); }
        TemporalScaler* newTemporalScaler(MTL::Device* d) { return (TemporalScaler*)NS::Object::sendMessage<id>(this, sel_registerName("newTemporalScalerWithDevice:"), (id)d); }
    };
}

struct RTVertex { float position[3]; float u, v; };

static MTL::Device*             _pDevice;
static MTL::CommandQueue*       _pCommandQueue;
static MTL::RenderPipelineState* _pPipelineState;
static MTL::Texture*            _pPaletteTexture;
static MTL::Texture*            _pIndexTextures[3];
static MTL::Texture*            _pIntermediateTexture;
static MetalFX::SpatialScaler*  _pSpatialScaler;
static CA::MetalLayer*          _pMetalLayer;
static int                      _currentFrame = 0;
static const int                MaxFramesInFlight = 3;
static short* _pZBufferMem;
static byte*  _pSurfCacheMem;
static MTL::Buffer* _pRTVertexBuffer = nullptr;
static MTL::Buffer* _pRTIndexBuffer = nullptr;
static MTL::AccelerationStructure* _pRTBLAS = nullptr;
static MTL::AccelerationStructure* _pRTInstancedAS = nullptr;
static MTL::Buffer* _pRTInstanceBuffer = nullptr;
static uint32_t _rtIndexCount = 0;

// IAS wrapping state. The shader always consumes an
// instance_acceleration_structure + an offsets buffer, so we always
// build one even in the default (unified-BLAS) path. A 1-instance IAS
// wrapping the unified BLAS with offset [0] is semantically equivalent
// to using the BLAS directly — we pay one extra BVH traversal level
// for the architectural flexibility.
//
// When r_rt_split_blas is on, the IAS becomes 2-instance (world BLAS +
// entity BLAS) and the offsets buffer carries [0, worldTriCount].
static MTL::Buffer*                _pInstanceOffsetsBuffer = nullptr;
static MTL::Buffer*                _pInstanceDescBuffer    = nullptr;
// Split-path extras — only populated when r_rt_split_blas is on.
static MTL::AccelerationStructure* _pWorldBLAS        = nullptr; // cached per-map
static MTL::AccelerationStructure* _pEntityBLAS       = nullptr; // per-frame
static MTL::Buffer*                _pWorldBLASVBuffer = nullptr;
static MTL::Buffer*                _pWorldBLASIBuffer = nullptr;
static MTL::Buffer*                _pEntityBLASVBuffer = nullptr;
static MTL::Buffer*                _pEntityBLASIBuffer = nullptr;
static uint32_t _worldTriCount = 0;

// ReSTIR DI: compact list of emissive world triangles. Populated once
// per map from the atlas sample at each triangle's center. The RT
// shader reservoir-samples candidates from this list each frame for
// many-light direct illumination.
static std::vector<uint32_t>       _emissiveTriIndices;
static MTL::Buffer*                _pEmissiveTriBuffer = nullptr;

// Argument-buffer state for the RT dispatch. _pRTArgBuffer holds 6
// device-pointer slots encoded by the argument encoder derived from
// the raytraceMain function at BuildPipeline time. The encoder retains
// the function so we keep it for the process lifetime.
static MTL::Function*              _pRTFunction           = nullptr;
static MTL::ArgumentEncoder*       _pRTArgEncoder         = nullptr;
static MTL::Buffer*                _pRTArgBuffer          = nullptr;

static MTL::ComputePipelineState* _pRTComputeState = nullptr;
static MTL::Texture* _pRTOutputTexture = nullptr;
static MTL::Texture* _pRTDepthTexture = nullptr;      // MetalFX temporal: depth
static MTL::Texture* _pRTMotionTexture = nullptr;      // MetalFX temporal: motion vectors
static MetalFX::TemporalScaler* _pTemporalScaler = nullptr;
static struct model_s* _lastWorldModel = nullptr;
static MTL::Texture* _pTextureAtlas = nullptr;
static MTL::Buffer* _pTriTexInfoBuffer = nullptr;
static MTL::Buffer* _pDynLightBuffer = nullptr;
static MTL::ComputePipelineState* _pDenoiseState = nullptr; // GPU bilateral denoiser
static MTL::Texture* _pDenoiseScratch = nullptr; // Ping-pong scratch for denoiser
static MTL::Texture* _pMFXOutputTexture = nullptr; // MetalFX upscaled output

// SVGF scaffolding. This is the temporal-reprojection half of SVGF —
// previous denoised frame is warped through current-frame motion vectors
// and blended with the current RT output. It's the cheap, honest
// foundation layer. Full SVGF adds variance estimation and disocclusion-
// aware weights on top, which will land once the history path is proven
// stable in real gameplay. See TECHNICAL.md for the migration plan.
static MTL::Texture* _pSVGFHistoryTexture  = nullptr;
static MTL::Texture* _pSVGFMomentsTexture  = nullptr;   // RG16: first & second luma moments
static MTL::Texture* _pSVGFVarianceTexture = nullptr;   // R16: per-pixel variance estimate
static MTL::ComputePipelineState* _pSVGFReprojectState = nullptr;
static MTL::ComputePipelineState* _pSVGFVarianceState  = nullptr;
// r_svgf: 0=off, 1=temporal reprojection only, 2=temporal reprojection
// + variance-aware bilateral modulation. Mode 2 is the full SVGF.
static cvar_t r_svgf = {(char*)"r_svgf", (char*)"0", 1};

// MetalFX Frame Interpolation (macOS 15+). The vendored metal-cpp on disk
// doesn't carry MTLFXFrameInterpolator.hpp, so all MetalFX-specific calls
// route through MQ_FrameInterp.m which imports the real ObjC headers and
// exposes a C API. We cache the interpolator handle + previous-frame
// color texture so each Encode call has the inputs it needs.
static cvar_t r_frameinterp = {(char*)"r_frameinterp", (char*)"0", 1};
static bool   _frameInterpolatorAvailable = false;
static void*  _pFrameInterpolator = nullptr;
static MTL::Texture* _pPrevColorTexture    = nullptr; // last frame's final composite
static MTL::Texture* _pFrameInterpOutput   = nullptr; // synthesized between-frame

extern "C" void* MQ_FI_Create(void *device, int w, int h, unsigned long pixelFormat);
extern "C" void  MQ_FI_Release(void *fi);
extern "C" int   MQ_FI_Encode(void *fi, void *cmdBuf,
                              void *currentColor, void *prevColor,
                              void *motion, void *depth,
                              void *output, float timeStepInSeconds);
extern "C" int   MQ_FI_IsAvailable(void);

// Window-layer helpers implemented in sys_macos.m.
extern "C" void  Sys_SetVsync(int enabled);
extern "C" void  Sys_SetFullscreen(int on);

// MTLResidencySet (macOS 15+) — pins long-lived resources so the driver
// doesn't re-evaluate their residency every frame.
extern "C" void* MQ_Residency_Create(void *device, const char *label);
extern "C" void  MQ_Residency_Release(void *set);
extern "C" void  MQ_Residency_AddResource(void *set, void *resource);
extern "C" void  MQ_Residency_Commit(void *set);
extern "C" void  MQ_Residency_RemoveAll(void *set);
extern "C" void  MQ_Residency_AttachToQueue(void *queue, void *set);
extern "C" int   MQ_Residency_IsAvailable(void);
static void* _pResidencySet = nullptr;

// Previous frame camera state for motion vector generation
static float _prevCamOrigin[4] = {0};
static float _prevCamForward[4] = {0};
static float _prevCamRight[4] = {0};
static float _prevCamUp[4] = {0};
static bool _temporalReset = true; // Reset on first frame / map change
static int _frameIndex = 0; // For jitter pattern

// Module-wide binary archive for zero-stutter shader caching. Created in
// BuildPipeline and serialized to disk in VID_Shutdown so the JIT
// compile cost from first launch is paid once per macOS version bump.
static MTL::BinaryArchive* _pShaderArchive = nullptr;

// Async BLAS event synchronization. _blasEvent is created once on first use
// in BuildRTXWorld and owned by the module for its lifetime. VID_Shutdown
// releases it — the prior code leaked one SharedEvent per process launch.
static MTL::SharedEvent* _blasEvent = nullptr;
static uint64_t _blasEventValue = 0;
static MTL::SharedEvent* _rtBLASEvent = nullptr;
static uint64_t _rtBLASEventValue = 0;

// Per-frame vertex/index buffer capacity. We grow on demand (never shrink)
// and memcpy into the existing shared-storage allocation instead of going
// through release()/newBuffer() on every frame. The old pattern churned
// three MTLBuffers per frame through the driver's allocator — this keeps
// the allocations warm and eliminates a meaningful chunk of CPU time in
// BuildRTXWorld on complex maps.
static size_t _rtVertexCapacity = 0; // in RTVertex units
static size_t _rtIndexCapacity  = 0; // in uint32_t units
struct GPUDynLight {
    float x, y, z, radius;
};
static int _numActiveLights = 0;

struct alignas(32) TriTexInfo {
    float atlas_u, atlas_v;    // atlas offset (normalized)
    float atlas_w, atlas_h;    // atlas region size (normalized)
    float tex_w, tex_h;        // original texture size (pixels)
    float pad0, pad1;
};

static std::vector<RTVertex> _worldVertices;
static std::vector<uint32_t> _worldIndices;
static std::vector<TriTexInfo> _worldTriTexInfos;

struct BSPMeshlet {
    uint32_t vertexOffset;      // Into global vertex buffer
    uint32_t vertexCount;       // Verts in this meshlet (max 64)
    uint32_t indexOffset;       // Into global index buffer
    uint32_t triangleCount;     // Tris in this meshlet (max 126)
    float boundingSphere[4];  // xyz=center, w=radius (for culling)
    float coneApex[4];        // For backface cone culling
    float coneAxis[4];        // xyz=axis, w=cutoff
};
static std::vector<BSPMeshlet> _worldMeshlets;
static MTL::Buffer* _pMeshletBuffer = nullptr;
static MTL::RenderPipelineState* _pMeshPipelineState = nullptr;
static bool _worldGeomBuilt = false;

// Per-triangle animation tracking: base texture pointer for animated surfaces
// -1 means not animated. Otherwise stores the base texture_t* for resolution.
struct AnimTriInfo { texture_t* baseTex; }; // null = not animated
static std::vector<AnimTriInfo> _worldAnimInfos;

// Cached atlas data for brush entity texture lookup
struct NormAtlasEntry { float u, v, w, h; int pw, ph; };
static std::vector<NormAtlasEntry> _worldAtlasEntries;
static std::vector<texture_t*> _worldTexPtrs;

struct SkinAtlasEntry {
    float atlas_u, atlas_v; // normalized atlas offset
    float atlas_w, atlas_h; // normalized atlas region
    int skinW, skinH;       // original skin dimensions
};
static std::vector<std::pair<model_t*, SkinAtlasEntry>> _skinAtlasCache;

static void BuildRTXWorld() {
    if (!cl.worldmodel) return;
    // Comprehensive BSP validity check — catches freed/partial models.
    // Model name sanity: must be non-empty and look like a path rather
    // than a specific prefix. The old 'm' prefix check was from when all
    // valid maps started with "maps/" but mods can load BSPs from custom
    // directories (e.g. "custom/start_remake.bsp").
    if (!cl.worldmodel->surfaces || !cl.worldmodel->edges ||
        !cl.worldmodel->vertexes || !cl.worldmodel->texinfo ||
        cl.worldmodel->numsurfaces <= 0 || cl.worldmodel->numvertexes <= 0 ||
        cl.worldmodel->name[0] == '\0') return;
    // Don't build RT world until map is fully loaded
    // scr_disabled_for_loading is set during map loading process
    extern qboolean scr_disabled_for_loading;
    if (cls.signon < SIGNONS || scr_disabled_for_loading) return;
    
    // Detect map changes: model pointer, name, or surface count change
    // NOTE: Quake reuses model_t slots in mod_known[] — pointer alone is NOT sufficient!
    static char _lastMapName[64] = {0};
    static int _lastNumSurfaces = 0;
    bool worldChanged = (cl.worldmodel != _lastWorldModel) ||
                        (strcmp(cl.worldmodel->name, _lastMapName) != 0) ||
                        (cl.worldmodel->numsurfaces != _lastNumSurfaces);
    
    if (worldChanged) {
        _lastWorldModel = cl.worldmodel;
        _lastNumSurfaces = cl.worldmodel->numsurfaces;
        strncpy(_lastMapName, cl.worldmodel->name, sizeof(_lastMapName) - 1);
        _lastMapName[sizeof(_lastMapName) - 1] = '\0';
        _worldGeomBuilt = false;
        _worldAtlasEntries.clear();
        _worldTexPtrs.clear();
        _skinAtlasCache.clear();
        _worldVertices.clear();
        _worldIndices.clear();
        _worldTriTexInfos.clear();
        _worldAnimInfos.clear();
        // Release old acceleration structure
        if (_pRTBLAS) { _pRTBLAS->release(); _pRTBLAS = nullptr; }
        if (_pRTInstancedAS) { _pRTInstancedAS->release(); _pRTInstancedAS = nullptr; }
        if (_pTextureAtlas) { _pTextureAtlas->release(); _pTextureAtlas = nullptr; }
        // CRITICAL: Return now. Rebuild on NEXT frame when BSP data is fully valid.
        return;
    }
    
    if (!_worldGeomBuilt) {
    // Build world geometry (once per map)
    
    std::vector<RTVertex> vertices;
    std::vector<uint32_t> indices;
    std::vector<TriTexInfo> triTexInfos;
    
    // === Phase 1: Build texture atlas ===
    // Collect unique textures and pack into a row-based atlas
    struct AtlasEntry { int x, y; int w, h; texture_t* tex; };
    std::vector<AtlasEntry> atlasEntries;
    int atlasWidth = 0, atlasHeight = 0;
    int curX = 0, curY = 0, rowHeight = 0;
    // Use the device's max 2D texture dimension (Apple Silicon supports up
    // to 16384), capped at 8192 to keep the atlas manageable and keep RT
    // sampling cheap. Falls back to 2048 if the query returns zero for any
    // reason.
    int MAX_ATLAS_WIDTH = 8192;
    if (_pDevice) {
        auto devMax = (int)_pDevice->supportsFamily(MTL::GPUFamilyApple7) ? 16384 : 8192;
        if (devMax < MAX_ATLAS_WIDTH) MAX_ATLAS_WIDTH = devMax;
    }
    if (MAX_ATLAS_WIDTH < 2048) MAX_ATLAS_WIDTH = 2048;
    
    // Map texture pointers to atlas entries
    std::vector<texture_t*> uniqueTextures;
    auto findOrAddTex = [&](texture_t* tex) -> int {
        if (!tex) return -1;
        for (int i = 0; i < (int)uniqueTextures.size(); i++)
            if (uniqueTextures[i] == tex) return i;
        uniqueTextures.push_back(tex);
        int tw = tex->width, th = tex->height;
        if (curX + tw > MAX_ATLAS_WIDTH) { curX = 0; curY += rowHeight; rowHeight = 0; }
        atlasEntries.push_back({curX, curY, tw, th, tex});
        curX += tw;
        if (th > rowHeight) rowHeight = th;
        int totalW = curX; if (totalW > atlasWidth) atlasWidth = totalW;
        atlasHeight = curY + rowHeight;
        return (int)uniqueTextures.size() - 1;
    };
    // === Phase 1b: Pre-scan ALL surfaces to collect textures (including door submodels) ===
    for (int i = 0; i < cl.worldmodel->numsurfaces; i++) {
        msurface_t* surf = &cl.worldmodel->surfaces[i];
        if (surf->flags & (SURF_DRAWSKY | SURF_DRAWBACKGROUND)) continue;
        mtexinfo_t* ti = surf->texinfo;
        texture_t* tex = ti ? ti->texture : nullptr;
        if (tex && strncmp(tex->name, "trigger", 7) != 0 &&
            strncmp(tex->name, "clip", 4) != 0 &&
            strncmp(tex->name, "skip", 4) != 0 &&
            strncmp(tex->name, "sky", 3) != 0) {
            findOrAddTex(tex); // ensure it's in the atlas
            // Also add all animation frames for this texture
            if (tex->anim_total > 0) {
                texture_t* anim = tex->anim_next;
                int safety = 0;
                while (anim && anim != tex && safety++ < 20) {
                    findOrAddTex(anim);
                    anim = anim->anim_next;
                }
                // Also add alternate animation chain
                if (tex->alternate_anims) {
                    anim = tex->alternate_anims;
                    safety = 0;
                    while (anim && safety++ < 20) {
                        findOrAddTex(anim);
                        anim = anim->anim_next;
                        if (anim == tex->alternate_anims) break;
                    }
                }
            }
        }
    }
    // Also scan brush models precached by the CURRENT map (ammo boxes, health, etc)
    // IMPORTANT: Use cl.model_precache[], NOT mod_known[] — mod_known contains
    // stale models from previous maps with dangling Hunk pointers!
    for (int mi = 1; mi < MAX_MODELS; mi++) {
        model_t* m = cl.model_precache[mi];
        if (!m || m->type != mod_brush || m == cl.worldmodel) continue;
        if (!m->surfaces || !m->texinfo || m->numsurfaces <= 0) continue;
        for (int si = m->firstmodelsurface; si < m->firstmodelsurface + m->nummodelsurfaces; si++) {
            if (si < 0 || si >= m->numsurfaces) continue;
            msurface_t* surf = &m->surfaces[si];
            if (surf->flags & (SURF_DRAWSKY | SURF_DRAWBACKGROUND | SURF_DRAWTURB)) continue;
            mtexinfo_t* ti = surf->texinfo;
            texture_t* tex = ti ? ti->texture : nullptr;
            if (tex && strncmp(tex->name, "trigger", 7) != 0 &&
                strncmp(tex->name, "clip", 4) != 0 &&
                tex->name[0] != '*') {
                findOrAddTex(tex);
            }
        }
    }
    
    // === Phase 2: Extract geometry with UVs ===
    // Only extract submodel 0 (static world) — doors/plats are submodels 1+ handled as brush entities
    int worldSurfStart = cl.worldmodel->firstmodelsurface;
    int worldSurfCount = cl.worldmodel->nummodelsurfaces;
    for (int i = worldSurfStart; i < worldSurfStart + worldSurfCount; i++) {
        msurface_t* surf = &cl.worldmodel->surfaces[i];
        if (surf->flags & (SURF_DRAWSKY | SURF_DRAWBACKGROUND)) continue;
        bool isLiquid = (surf->flags & SURF_DRAWTURB) != 0;
        
        mtexinfo_t* ti = surf->texinfo;
        texture_t* tex = ti ? ti->texture : nullptr;
        
        // Skip invisible surfaces
        if (tex && (strncmp(tex->name, "trigger", 7) == 0 ||
                    strncmp(tex->name, "clip", 4) == 0 ||
                    strncmp(tex->name, "skip", 4) == 0 ||
                    strncmp(tex->name, "hint", 4) == 0 ||
                    strncmp(tex->name, "sky", 3) == 0)) continue;
        if (ti && (ti->flags & TEX_SPECIAL) && !isLiquid) continue;
        
        // Track base texture for per-frame animation resolution
        texture_t* baseTex = (tex && tex->anim_total > 0) ? tex : nullptr;
        
        int texIdx = findOrAddTex(tex);
        float texW = tex ? (float)tex->width : 64.0f;
        float texH = tex ? (float)tex->height : 64.0f;
        
        std::vector<uint32_t> face_indices;
        for (int j = 0; j < surf->numedges; j++) {
            int e = cl.worldmodel->surfedges[surf->firstedge + j];
            int v_idx = (e > 0) ? cl.worldmodel->edges[e].v[0] : cl.worldmodel->edges[-e].v[1];
            if (v_idx < 0 || v_idx >= cl.worldmodel->numvertexes) continue;
            float* v_pos = cl.worldmodel->vertexes[v_idx].position;
            
            // Compute UV from texinfo vecs
            float s = v_pos[0] * ti->vecs[0][0] + v_pos[1] * ti->vecs[0][1] + v_pos[2] * ti->vecs[0][2] + ti->vecs[0][3];
            float t = v_pos[0] * ti->vecs[1][0] + v_pos[1] * ti->vecs[1][1] + v_pos[2] * ti->vecs[1][2] + ti->vecs[1][3];
            
            RTVertex vert;
            vert.position[0] = v_pos[0]; vert.position[1] = v_pos[1]; vert.position[2] = v_pos[2];
            vert.u = s; vert.v = t;  // raw texel-space UVs
            vertices.push_back(vert);
            face_indices.push_back((uint32_t)vertices.size() - 1);
        }
        
        // Fan triangulation
        for (size_t j = 1; j < face_indices.size() - 1; j++) {
            indices.push_back(face_indices[0]); indices.push_back(face_indices[j]); indices.push_back(face_indices[j+1]);
            
            // Per-triangle texture info
            TriTexInfo tti = {};
            if (texIdx >= 0 && texIdx < (int)atlasEntries.size()) {
                tti.atlas_u = (float)atlasEntries[texIdx].x;
                tti.atlas_v = (float)atlasEntries[texIdx].y;
                tti.atlas_w = (float)atlasEntries[texIdx].w;
                tti.atlas_h = (float)atlasEntries[texIdx].h;
            }
            tti.tex_w = texW; tti.tex_h = texH;
            // Compute average BSP lightmap intensity for this surface
            if (surf->samples && !isLiquid) {
                int ssize = (surf->extents[0] >> 4) + 1;
                int tsize = (surf->extents[1] >> 4) + 1;
                int numSamples = ssize * tsize;
                if (numSamples > 0 && numSamples < 65536) {
                    float total = 0;
                    for (int si = 0; si < numSamples; si++)
                        total += surf->samples[si];
                    tti.pad0 = (total / numSamples) / 255.0f;
                } else {
                    tti.pad0 = 0.5f;
                }
            } else {
                tti.pad0 = isLiquid ? 0.6f : 0.5f;
            }
            // Mark liquid type: 1=water, 2=lava, 3=slime, 4=tele
            if (isLiquid && tex) {
                if (tex->name[0] == '*') {
                    if (strncmp(tex->name+1, "lava", 4) == 0) tti.pad1 = 2.0f;
                    else if (strncmp(tex->name+1, "slime", 5) == 0) tti.pad1 = 3.0f;
                    else if (strncmp(tex->name+1, "tele", 4) == 0) tti.pad1 = 4.0f;
                    else tti.pad1 = 1.0f; // water
                } else tti.pad1 = 1.0f;
            }
            triTexInfos.push_back(tti);
            // Track animation info for this triangle
            AnimTriInfo ati; ati.baseTex = baseTex;
            // Store original texinfo for per-frame resolve
            _worldAnimInfos.push_back(ati);
        }
    }
    
    if (vertices.empty()) return;
    
    // === Phase 2a: Cluster BSP geometry into Meshlets (Max 64 verts / 126 tris) ===
    _worldMeshlets.clear();
    const uint32_t MAX_VERTS = 64;
    const uint32_t MAX_TRIS = 126;
    
    // Two-pass meshlet build: pack triangles, then compute a real bounding
    // sphere for each meshlet. The old code hardcoded radius=9999 which
    // disabled frustum culling entirely in the object shader.
    BSPMeshlet currentMeshlet = {};
    currentMeshlet.vertexOffset = 0;
    currentMeshlet.indexOffset = 0;
    // Track min/max for this meshlet's current accumulation.
    float mMinX = 1e30f, mMinY = 1e30f, mMinZ = 1e30f;
    float mMaxX = -1e30f, mMaxY = -1e30f, mMaxZ = -1e30f;

    auto finalizeSphere = [&]() {
        float cx = 0.5f * (mMinX + mMaxX);
        float cy = 0.5f * (mMinY + mMaxY);
        float cz = 0.5f * (mMinZ + mMaxZ);
        float dx = mMaxX - cx;
        float dy = mMaxY - cy;
        float dz = mMaxZ - cz;
        float r  = sqrtf(dx*dx + dy*dy + dz*dz);
        if (r < 1.0f) r = 1.0f; // defensive minimum
        currentMeshlet.boundingSphere[0] = cx;
        currentMeshlet.boundingSphere[1] = cy;
        currentMeshlet.boundingSphere[2] = cz;
        currentMeshlet.boundingSphere[3] = r;
        currentMeshlet.coneAxis[3] = -1.0f; // cone culling still disabled
    };

    for (size_t i = 0; i < indices.size(); i += 3) {
        if (currentMeshlet.triangleCount >= MAX_TRIS) {
            finalizeSphere();
            _worldMeshlets.push_back(currentMeshlet);
            currentMeshlet = {};
            currentMeshlet.indexOffset = (uint32_t)i;
            mMinX = mMinY = mMinZ = 1e30f;
            mMaxX = mMaxY = mMaxZ = -1e30f;
        }
        currentMeshlet.triangleCount++;
        uint32_t i0 = indices[i], i1 = indices[i+1], i2 = indices[i+2];
        RTVertex& v0 = vertices[i0];
        RTVertex& v1 = vertices[i1];
        RTVertex& v2 = vertices[i2];
        for (int k = 0; k < 3; k++) {
            float x = (k == 0 ? v0.position[0] : k == 1 ? v1.position[0] : v2.position[0]);
            float y = (k == 0 ? v0.position[1] : k == 1 ? v1.position[1] : v2.position[1]);
            float z = (k == 0 ? v0.position[2] : k == 1 ? v1.position[2] : v2.position[2]);
            if (x < mMinX) mMinX = x; if (x > mMaxX) mMaxX = x;
            if (y < mMinY) mMinY = y; if (y > mMaxY) mMaxY = y;
            if (z < mMinZ) mMinZ = z; if (z > mMaxZ) mMaxZ = z;
        }
    }
    if (currentMeshlet.triangleCount > 0) {
        finalizeSphere();
        _worldMeshlets.push_back(currentMeshlet);
    }
    
    if (_pMeshletBuffer) _pMeshletBuffer->release();
    _pMeshletBuffer = _pDevice->newBuffer(_worldMeshlets.data(), _worldMeshlets.size() * sizeof(BSPMeshlet), MTL::ResourceStorageModeShared);
    
    // === Phase 2b: Add entity (alias model) skins to atlas ===
    _skinAtlasCache.clear();
    extern unsigned char *host_basepal;
    for (int mi = 1; mi < MAX_MODELS; mi++) {
        model_t* mod = cl.model_precache[mi];
        if (!mod || mod->type != mod_alias) continue;
        aliashdr_t* pahdr = (aliashdr_t*)Mod_Extradata(mod);
        if (!pahdr) continue;
        mdl_t* pmdl = (mdl_t*)((byte*)pahdr + pahdr->model);
        if (pmdl->numskins <= 0 || pmdl->skinwidth <= 0 || pmdl->skinheight <= 0) continue;
        
        // Get skin 0
        maliasskindesc_t* pskindesc = (maliasskindesc_t*)((byte*)pahdr + pahdr->skindesc);
        byte* skinPixels = (byte*)pahdr + pskindesc->skin;
        int sw = pmdl->skinwidth, sh = pmdl->skinheight;
        
        // Pack into atlas using the same row-based packing
        if (curX + sw > MAX_ATLAS_WIDTH) { curX = 0; curY += rowHeight; rowHeight = 0; }
        int skinAX = curX, skinAY = curY;
        curX += sw;
        if (sh > rowHeight) rowHeight = sh;
        int totalW = curX; if (totalW > atlasWidth) atlasWidth = totalW;
        atlasHeight = curY + rowHeight;
        
        // Store atlas entry (will be normalized after atlas size is finalized)
        SkinAtlasEntry sae;
        sae.atlas_u = (float)skinAX; sae.atlas_v = (float)skinAY;
        sae.atlas_w = (float)sw; sae.atlas_h = (float)sh;
        sae.skinW = sw; sae.skinH = sh;
        _skinAtlasCache.push_back({mod, sae});
        
        // We'll write the actual pixels after atlas size is finalized
        // Store a reference for later: atlasEntries can track skin entries too
        atlasEntries.push_back({skinAX, skinAY, sw, sh, nullptr}); // nullptr tex = skin
        // We'll need to blit skin pixels directly; store index
    }
    
    // === Phase 3: Build texture atlas Metal texture ===
    // Pad atlas dimensions to power of 2 for safety
    int aw = 1; while (aw < atlasWidth) aw *= 2;
    int ah = 1; while (ah < atlasHeight) ah *= 2;
    if (aw < 1) aw = 1; if (ah < 1) ah = 1;
    
    // Normalize atlas coords
    for (auto& tti : triTexInfos) {
        tti.atlas_u /= (float)aw;
        tti.atlas_v /= (float)ah;
        tti.atlas_w /= (float)aw;
        tti.atlas_h /= (float)ah;
    }
    
    // Build RGBA atlas pixel data (GCD parallel — each entry is independent)
    std::vector<uint32_t> atlasPixels(aw * ah, 0xFF000000); // black default
    uint32_t* pixelPtr = atlasPixels.data();
    byte* pal = host_basepal;
    size_t entryCount = atlasEntries.size();
    auto* entriesPtr = atlasEntries.data();
    {
        // Parallel atlas pixel copy — each entry writes to non-overlapping region
        MQ_ParallelFor(entryCount, 0, nullptr, ^(size_t ei) {
            auto& entry = entriesPtr[ei];
            if (!entry.tex) return;
            byte* texPixels = (byte*)entry.tex + entry.tex->offsets[0];
            for (int ty = 0; ty < entry.h; ty++) {
                for (int tx = 0; tx < entry.w; tx++) {
                    byte palIdx = texPixels[ty * entry.w + tx];
                    int ax = entry.x + tx, ay = entry.y + ty;
                    if (ax < aw && ay < ah) {
                        // Quake's palette index 255 is the transparent
                        // color. Encoding alpha=0 lets the RT shader
                        // detect cutout surfaces (railings, fences) by
                        // sampling alpha after a hit and either skipping
                        // the hit or blending through.
                        uint32_t r = pal[palIdx * 3 + 0];
                        uint32_t g = pal[palIdx * 3 + 1];
                        uint32_t b = pal[palIdx * 3 + 2];
                        uint32_t a = (palIdx == 255) ? 0x00000000 : 0xFF000000;
                        pixelPtr[ay * aw + ax] = r | (g << 8) | (b << 16) | a;
                    }
                }
            }
        });
    }
    
    // Write entity skin pixels into atlas
    for (auto& sc : _skinAtlasCache) {
        model_t* mod = sc.first;
        SkinAtlasEntry& sae = sc.second;
        aliashdr_t* pahdr = (aliashdr_t*)Mod_Extradata(mod);
        if (!pahdr) continue;
        mdl_t* pmdl = (mdl_t*)((byte*)pahdr + pahdr->model);
        maliasskindesc_t* pskindesc = (maliasskindesc_t*)((byte*)pahdr + pahdr->skindesc);
        byte* skinPix = (byte*)pahdr + pskindesc->skin;
        int sx0 = (int)sae.atlas_u, sy0 = (int)sae.atlas_v;
        for (int ty = 0; ty < sae.skinH; ty++) {
            for (int tx = 0; tx < sae.skinW; tx++) {
                byte palIdx = skinPix[ty * sae.skinW + tx];
                int px = sx0 + tx, py = sy0 + ty;
                if (px < aw && py < ah) {
                    uint32_t r = host_basepal[palIdx * 3 + 0];
                    uint32_t g = host_basepal[palIdx * 3 + 1];
                    uint32_t b = host_basepal[palIdx * 3 + 2];
                    uint32_t a = (palIdx == 255) ? 0x00000000 : 0xFF000000;
                    atlasPixels[py * aw + px] = r | (g << 8) | (b << 16) | a;
                }
            }
        }
        // Normalize skin atlas entries to [0,1] range
        sae.atlas_u /= (float)aw;
        sae.atlas_v /= (float)ah;
        sae.atlas_w /= (float)aw;
        sae.atlas_h /= (float)ah;
    }
    
    if (_pTextureAtlas) _pTextureAtlas->release();
    {
        bool upscale = MQ_GetSettings()->coreml_textures != 0;
        int texW = aw, texH = ah;
        if (upscale) {
            texW = aw * 4;
            texH = ah * 4;
            // Respect the device's max texture dimension. If 4× blows
            // past the limit, silently cap the upscale to whatever fits.
            int devMax = _pDevice->supportsFamily(MTL::GPUFamilyApple7) ? 16384 : 8192;
            while (texW > devMax || texH > devMax) {
                texW >>= 1;
                texH >>= 1;
            }
        }
        auto* atlasDesc = MTL::TextureDescriptor::texture2DDescriptor(MTL::PixelFormatRGBA8Unorm, texW, texH, false);
        atlasDesc->setUsage(MTL::TextureUsageShaderRead | MTL::TextureUsageShaderWrite);
        _pTextureAtlas = _pDevice->newTexture(atlasDesc);

        if (!upscale || texW == aw) {
            _pTextureAtlas->replaceRegion(MTL::Region(0, 0, aw, ah), 0, atlasPixels.data(), aw * 4);
        } else {
            // Upload the low-res atlas into a scratch texture, then route
            // it through MQ_CoreML_UpscaleTexture (MPSGraph resizeBilinear
            // stand-in for Real-ESRGAN). Replaces stand-in with a trained
            // model later by swapping MQ_CoreML_UpscaleTexture's body — no
            // call-site changes.
            std::vector<uint8_t> upscaled((size_t)texW * texH * 4, 0);
            // Simple per-chunk processing: the upscaler wants small-ish
            // inputs. We process the atlas in 4× tiles so the MPS graph
            // compile/run cost is bounded per invocation.
            extern int MQ_CoreML_UpscaleTexture(const uint8_t *in, uint8_t *out, int inW, int inH);
            int rc = MQ_CoreML_UpscaleTexture(
                reinterpret_cast<const uint8_t*>(atlasPixels.data()),
                upscaled.data(), aw, ah);
            if (rc != 0) {
                // Upscale failed — fall back to point upload at low res.
                Con_Printf("CoreML atlas upscale failed (rc=%d); using native res\n", rc);
                if (_pTextureAtlas) _pTextureAtlas->release();
                auto* fallbackDesc = MTL::TextureDescriptor::texture2DDescriptor(MTL::PixelFormatRGBA8Unorm, aw, ah, false);
                _pTextureAtlas = _pDevice->newTexture(fallbackDesc);
                _pTextureAtlas->replaceRegion(MTL::Region(0, 0, aw, ah), 0, atlasPixels.data(), aw * 4);
            } else {
                _pTextureAtlas->replaceRegion(MTL::Region(0, 0, texW, texH), 0, upscaled.data(), texW * 4);
                Con_Printf("CoreML atlas upscaled: %dx%d -> %dx%d\n", aw, ah, texW, texH);
            }
        }
    }

    // Residency: add the freshly-built atlas to the resident set so the
    // driver pins it in VRAM for the duration of the map. We remove
    // everything first because a map transition replaces the atlas and
    // the previous pointer would no longer be valid.
    if (_pResidencySet && _pTextureAtlas) {
        MQ_Residency_RemoveAll(_pResidencySet);
        MQ_Residency_AddResource(_pResidencySet, _pTextureAtlas);
        if (_pMeshletBuffer) MQ_Residency_AddResource(_pResidencySet, _pMeshletBuffer);
        MQ_Residency_Commit(_pResidencySet);
    }
    
    // Cache world geometry and atlas data for brush entity lookup
    _worldVertices = vertices;
    _worldIndices = indices;
    _worldTriTexInfos = triTexInfos;
    _worldTexPtrs = uniqueTextures;
    _worldAtlasEntries.clear();
    for (auto& ae : atlasEntries) {
        NormAtlasEntry ne;
        ne.u = (float)ae.x / (float)aw;
        ne.v = (float)ae.y / (float)ah;
        ne.w = (float)ae.w / (float)aw;
        ne.h = (float)ae.h / (float)ah;
        ne.pw = ae.w; ne.ph = ae.h;
        _worldAtlasEntries.push_back(ne);
    }

    // === Build emissive-triangle list for ReSTIR DI ===
    //
    // For each world triangle, sample the center of its atlas region and
    // classify as emissive using the same heuristic the RT shader uses at
    // hit points (bright OR highly chromatic). The resulting list lets
    // the shader do real many-light sampling — instead of relying on the
    // 16-entry cl_dlights array for all direct illumination, every lit
    // surface in the world (torches, lava, teleporter panels, window
    // fixtures) can be reservoir-sampled as a light source.
    _emissiveTriIndices.clear();
    float maxLumSeen = 0.0f, maxChromaSeen = 0.0f;
    int skipped = 0;
    for (size_t ti = 0; ti < _worldTriTexInfos.size(); ti++) {
        const TriTexInfo& tti = _worldTriTexInfos[ti];
        if (tti.atlas_w < 0.0f || tti.tex_w < 1.0f || tti.tex_h < 1.0f) { skipped++; continue; }

        // 8×8 sampling grid across the triangle's texture so small
        // emissive regions (torch flames, crystal tips) aren't missed
        // by a single center sample.
        int stepX = std::max(1, (int)tti.tex_w / 8);
        int stepY = std::max(1, (int)tti.tex_h / 8);
        int ax0 = (int)(tti.atlas_u * aw);
        int ay0 = (int)(tti.atlas_v * ah);
        float peakLum = 0.0f, peakMaxCh = 0.0f, peakChroma = 0.0f;
        for (int sy = 0; sy < (int)tti.tex_h; sy += stepY) {
            for (int sx = 0; sx < (int)tti.tex_w; sx += stepX) {
                int ax = ax0 + sx;
                int ay = ay0 + sy;
                if (ax < 0 || ax >= aw || ay < 0 || ay >= ah) continue;
                uint32_t pix = atlasPixels[ay * aw + ax];
                float r = ((pix >> 0)  & 0xFF) / 255.0f;
                float g = ((pix >> 8)  & 0xFF) / 255.0f;
                float b = ((pix >> 16) & 0xFF) / 255.0f;
                float lum    = 0.2126f * r + 0.7152f * g + 0.0722f * b;
                float maxCh  = std::max(std::max(r, g), b);
                float minCh  = std::min(std::min(r, g), b);
                float chroma = maxCh - minCh;
                if (lum > peakLum)       peakLum = lum;
                if (maxCh > peakMaxCh)   peakMaxCh = maxCh;
                if (chroma > peakChroma) peakChroma = chroma;
            }
        }
        if (peakLum > maxLumSeen) maxLumSeen = peakLum;
        if (peakChroma > maxChromaSeen) maxChromaSeen = peakChroma;
        bool emissive = (peakLum > 0.7f) || (peakMaxCh > 0.7f && peakChroma > 0.4f);
        if (emissive) _emissiveTriIndices.push_back((uint32_t)ti);
    }
    Con_Printf("ReSTIR: %zu emissive world tris (skipped %d, max luma %.2f, max chroma %.2f, of %zu)\n",
               _emissiveTriIndices.size(), skipped, (double)maxLumSeen, (double)maxChromaSeen,
               _worldTriTexInfos.size());

    if (_pEmissiveTriBuffer) { _pEmissiveTriBuffer->release(); _pEmissiveTriBuffer = nullptr; }
    if (!_emissiveTriIndices.empty()) {
        _pEmissiveTriBuffer = _pDevice->newBuffer(
            _emissiveTriIndices.data(),
            _emissiveTriIndices.size() * sizeof(uint32_t),
            MTL::ResourceStorageModeShared);
    }

    _worldGeomBuilt = true;
    } // end if (!_worldGeomBuilt)
    
    // === Per-frame: world + entities ===
    std::vector<RTVertex> frameVertices = _worldVertices;
    std::vector<uint32_t> frameIndices = _worldIndices;
    std::vector<TriTexInfo> frameTriTexInfos = _worldTriTexInfos;
    
    // === Per-frame: Resolve animated textures ===
    // Update atlas indices for triangles with animated textures (+0/+1 sequences)
    for (size_t ti = 0; ti < _worldAnimInfos.size() && ti < frameTriTexInfos.size(); ti++) {
        texture_t* baseTex = _worldAnimInfos[ti].baseTex;
        if (!baseTex || baseTex->anim_total <= 0) continue;
        
        // Resolve current animation frame
        int reletive = (int)(cl.time * 10.0) % baseTex->anim_total;
        texture_t* animTex = baseTex;
        int count = 0;
        while (animTex && (animTex->anim_min > reletive || animTex->anim_max <= reletive)) {
            animTex = animTex->anim_next;
            if (!animTex || ++count > 100) { animTex = baseTex; break; }
        }
        
        // Find this texture's atlas index
        for (int ai = 0; ai < (int)_worldTexPtrs.size(); ai++) {
            if (_worldTexPtrs[ai] == animTex && ai < (int)_worldAtlasEntries.size()) {
                NormAtlasEntry& ae = _worldAtlasEntries[ai];
                frameTriTexInfos[ti].atlas_u = ae.u;
                frameTriTexInfos[ti].atlas_v = ae.v;
                frameTriTexInfos[ti].atlas_w = ae.w;
                frameTriTexInfos[ti].atlas_h = ae.h;
                break;
            }
        }
    }
    
    // === Phase 5: Extract entity geometry with skin textures ===
    extern int cl_numvisedicts;
    extern entity_t *cl_visedicts[];
    extern unsigned char *host_basepal;
    
    // Helper lambda to add an alias entity
    auto addAliasEntity = [&](entity_t* ent, bool isViewmodel) {
        if (!ent || !ent->model || ent->model->type != mod_alias) return;
        aliashdr_t* pahdr = (aliashdr_t*)Mod_Extradata(ent->model);
        if (!pahdr) return;
        mdl_t* pmdl = (mdl_t*)((byte*)pahdr + pahdr->model);
        
        // Get animation frame vertices
        int frame = ent->frame;
        if (frame >= pmdl->numframes || frame < 0) frame = 0;
        trivertx_t* pverts = nullptr;
        if (pahdr->frames[frame].type == ALIAS_SINGLE) {
            pverts = (trivertx_t*)((byte*)pahdr + pahdr->frames[frame].frame);
        } else {
            maliasgroup_t* pg = (maliasgroup_t*)((byte*)pahdr + pahdr->frames[frame].frame);
            pverts = (trivertx_t*)((byte*)pahdr + pg->frames[0].frame);
        }
        if (!pverts) return;
        
        // Look up skin atlas entry for this model
        SkinAtlasEntry* skinEntry = nullptr;
        for (auto& sc : _skinAtlasCache) {
            if (sc.first == ent->model) { skinEntry = &sc.second; break; }
        }
        int skinW = skinEntry ? skinEntry->skinW : 64;
        int skinH = skinEntry ? skinEntry->skinH : 64;
        
        // Get st verts for UVs
        stvert_t* pstverts = (stvert_t*)((byte*)pahdr + pahdr->stverts);
        mtriangle_t* ptris = (mtriangle_t*)((byte*)pahdr + pahdr->triangles);
        
        // Build entity transform
        vec3_t fwd, right, up;
        vec3_t angles;
        if (isViewmodel) {
            extern refdef_t r_refdef;
            extern vec3_t vpn, vright, vup;
            VectorCopy(vpn, fwd); VectorCopy(vright, right); VectorCopy(vup, up);
        } else {
            angles[0] = -ent->angles[0];
            angles[1] = ent->angles[1];
            angles[2] = ent->angles[2];
            AngleVectors(angles, fwd, right, up);
        }
        
        
        // Emit 3 unique vertices per triangle with seam-corrected UVs
        for (int ti = 0; ti < pmdl->numtris; ti++) {
            uint32_t triBase = (uint32_t)frameVertices.size();
            for (int tv = 0; tv < 3; tv++) {
                int vi = ptris[ti].vertindex[tv];
                float lx = pverts[vi].v[0] * pmdl->scale[0] + pmdl->scale_origin[0];
                float ly = pverts[vi].v[1] * pmdl->scale[1] + pmdl->scale_origin[1];
                float lz = pverts[vi].v[2] * pmdl->scale[2] + pmdl->scale_origin[2];
                float wx = ent->origin[0] + lx * fwd[0] - ly * right[0] + lz * up[0];
                float wy = ent->origin[1] + lx * fwd[1] - ly * right[1] + lz * up[1];
                float wz = ent->origin[2] + lx * fwd[2] - ly * right[2] + lz * up[2];
                
                // Per-vertex seam-corrected UV (s,t are fixed-point 16.16, shift right by 16)
                float su = (float)(pstverts[vi].s >> 16);
                float sv = (float)(pstverts[vi].t >> 16);
                if (!ptris[ti].facesfront && pstverts[vi].onseam)
                    su += (float)(skinW / 2);
                
                RTVertex v;
                v.position[0] = wx; v.position[1] = wy; v.position[2] = wz;
                v.u = su; v.v = sv;
                frameVertices.push_back(v);
            }
            frameIndices.push_back(triBase);
            frameIndices.push_back(triBase + 1);
            frameIndices.push_back(triBase + 2);
            
            TriTexInfo tti = {};
            if (skinEntry) {
                tti.atlas_u = skinEntry->atlas_u;
                tti.atlas_v = skinEntry->atlas_v;
                tti.atlas_w = skinEntry->atlas_w;
                tti.atlas_h = skinEntry->atlas_h;
                tti.tex_w = (float)skinW;
                tti.tex_h = (float)skinH;
            } else {
                tti.atlas_w = -1.0f;
                tti.tex_w = 64; tti.tex_h = 64;
            }
            frameTriTexInfos.push_back(tti);
        }
    };
    
    // Helper: add brush model entity (doors, platforms, lifts)
    auto addBrushEntity = [&](entity_t* ent) {
        if (!ent || !ent->model || ent->model->type != mod_brush) return;
        model_t* mod = ent->model;
        // Only iterate this submodel's surfaces, NOT all worldmodel surfaces
        int surfStart = mod->firstmodelsurface;
        int surfEnd = surfStart + mod->nummodelsurfaces;
        for (int si = surfStart; si < surfEnd; si++) {
            msurface_t* surf = &mod->surfaces[si];
            if (surf->flags & (SURF_DRAWSKY | SURF_DRAWBACKGROUND | SURF_DRAWTURB)) continue;
            mtexinfo_t* ti = surf->texinfo;
            texture_t* tex = ti ? ti->texture : nullptr;
            if (tex && (strncmp(tex->name, "trigger", 7) == 0 ||
                        strncmp(tex->name, "clip", 4) == 0 ||
                        strncmp(tex->name, "skip", 4) == 0 ||
                        tex->name[0] == '*')) continue;
            if (ti && (ti->flags & TEX_SPECIAL)) continue;
            
            // Find this texture in the cached world atlas
            int texIdx = -1;
            if (tex) {
                for (int ui = 0; ui < (int)_worldTexPtrs.size(); ui++) {
                    if (_worldTexPtrs[ui] == tex) { texIdx = ui; break; }
                }
            }
            float texW = tex ? (float)tex->width : 64.0f;
            float texH = tex ? (float)tex->height : 64.0f;
            
            // Compute BSP lightmap for this surface
            float brushLight = 0.5f;
            if (surf->samples) {
                int ssize = (surf->extents[0] >> 4) + 1;
                int tsize = (surf->extents[1] >> 4) + 1;
                int ns = ssize * tsize;
                if (ns > 0 && ns < 65536) {
                    float total = 0;
                    for (int si2 = 0; si2 < ns; si2++) total += surf->samples[si2];
                    brushLight = (total / ns) / 255.0f;
                }
            }
            
            std::vector<uint32_t> face_idx;
            for (int j = 0; j < surf->numedges; j++) {
                int edgeIdx = mod->surfedges[surf->firstedge + j];
                int vertIdx = (edgeIdx >= 0) ? mod->edges[edgeIdx].v[0] : mod->edges[-edgeIdx].v[1];
                mvertex_t* mv = &mod->vertexes[vertIdx];
                float wx = mv->position[0] + ent->origin[0];
                float wy = mv->position[1] + ent->origin[1];
                float wz = mv->position[2] + ent->origin[2];
                float u = 0, v = 0;
                if (ti) {
                    u = mv->position[0]*ti->vecs[0][0] + mv->position[1]*ti->vecs[0][1] + mv->position[2]*ti->vecs[0][2] + ti->vecs[0][3];
                    v = mv->position[0]*ti->vecs[1][0] + mv->position[1]*ti->vecs[1][1] + mv->position[2]*ti->vecs[1][2] + ti->vecs[1][3];
                }
                RTVertex rv; rv.position[0] = wx; rv.position[1] = wy; rv.position[2] = wz;
                rv.u = u; rv.v = v;
                face_idx.push_back((uint32_t)frameVertices.size());
                frameVertices.push_back(rv);
            }
            for (int j = 1; j + 1 < (int)face_idx.size(); j++) {
                frameIndices.push_back(face_idx[0]);
                frameIndices.push_back(face_idx[j]);
                frameIndices.push_back(face_idx[j+1]);
                TriTexInfo tti = {};
                if (texIdx >= 0 && texIdx < (int)_worldAtlasEntries.size()) {
                    tti.atlas_u = _worldAtlasEntries[texIdx].u;
                    tti.atlas_v = _worldAtlasEntries[texIdx].v;
                    tti.atlas_w = _worldAtlasEntries[texIdx].w;
                    tti.atlas_h = _worldAtlasEntries[texIdx].h;
                } else {
                    tti.atlas_w = -1.0f;
                }
                tti.tex_w = texW; tti.tex_h = texH;
                tti.pad0 = brushLight;
                frameTriTexInfos.push_back(tti);
            }
        }
    };
    
    // Process all visible entities
    for (int ei = 0; ei < cl_numvisedicts; ei++) {
        entity_t* ent = cl_visedicts[ei];
        if (!ent || !ent->model) continue;
        if (ent->model->type == mod_alias) addAliasEntity(ent, false);
        else if (ent->model->type == mod_brush) addBrushEntity(ent);
    }
    
    // Add viewmodel (player's weapon)
    if (cl.viewent.model) {
        addAliasEntity(&cl.viewent, true);
    }
    
    // === Phase 5b: Extract dynamic lights ===
    extern dlight_t cl_dlights[];
    GPUDynLight gpuLights[MAX_DLIGHTS];
    _numActiveLights = 0;
    for (int i = 0; i < MAX_DLIGHTS; i++) {
        if (cl_dlights[i].die < cl.time || cl_dlights[i].radius <= 0) continue;
        gpuLights[_numActiveLights].x = cl_dlights[i].origin[0];
        gpuLights[_numActiveLights].y = cl_dlights[i].origin[1];
        gpuLights[_numActiveLights].z = cl_dlights[i].origin[2];
        gpuLights[_numActiveLights].radius = cl_dlights[i].radius;
        _numActiveLights++;
        if (_numActiveLights >= 16) break; // limit for shader
    }
    
    if (frameVertices.empty()) return;
    
    // === Phase 6: Build BLAS (every frame with entities) ===
    // Unified BLAS by design — see GEMINI.md §5. Splitting world and
    // entities into separate BLAS objects breaks the 1:1 primitive_id →
    // TriTexInfo mapping the shader depends on. Instead, keep geometry in
    // a single BLAS and eliminate the per-frame buffer allocation churn
    // via grow-only reuse below.
    //
    // Frame-to-frame refit: if the triangle count hasn't changed we can
    // refit the existing BLAS in place instead of rebuilding from
    // scratch — 3-5× faster on Apple Silicon. Stable-topology frames
    // (monsters breathing, projectiles flying) hit this path.
    static uint32_t _lastBLASTriCount = 0;
    bool canRefit = (_pRTBLAS != nullptr) &&
                    ((uint32_t)(frameIndices.size() / 3) == _lastBLASTriCount) &&
                    _lastBLASTriCount > 0;
    if (!canRefit && _pRTBLAS) { _pRTBLAS->release(); _pRTBLAS = nullptr; }
    if (_pRTInstanceBuffer) { _pRTInstanceBuffer->release(); _pRTInstanceBuffer = nullptr; }
    if (_pRTInstancedAS) { _pRTInstancedAS->release(); _pRTInstancedAS = nullptr; }
    if (_pTriTexInfoBuffer) _pTriTexInfoBuffer->release();
    if (_pDynLightBuffer) _pDynLightBuffer->release();

    // Guard against empty geometry (can happen during map transitions)
    if (frameVertices.empty() || frameIndices.empty() || frameIndices.size() < 3) {
        _pRTBLAS = nullptr; _pTriTexInfoBuffer = nullptr; _pDynLightBuffer = nullptr;
        return;
    }

    // Per-frame allocation (the original pattern). The buffer-reuse
    // optimization caused visual regressions when the BLAS descriptor
    // referenced a buffer whose size didn't match the live contents,
    // so reverting for now. The churn is real but correctness wins.
    if (_pRTVertexBuffer) _pRTVertexBuffer->release();
    if (_pRTIndexBuffer)  _pRTIndexBuffer->release();
    _pRTVertexBuffer = _pDevice->newBuffer(frameVertices.data(), frameVertices.size() * sizeof(RTVertex), MTL::ResourceStorageModeShared);
    _pRTIndexBuffer  = _pDevice->newBuffer(frameIndices.data(),  frameIndices.size()  * sizeof(uint32_t), MTL::ResourceStorageModeShared);
    _rtIndexCount = (uint32_t)frameIndices.size();
    
    auto* geomDesc = MTL::AccelerationStructureTriangleGeometryDescriptor::alloc()->init();
    geomDesc->setVertexBuffer(_pRTVertexBuffer); geomDesc->setVertexStride(sizeof(RTVertex));
    geomDesc->setIndexBuffer(_pRTIndexBuffer); geomDesc->setIndexType(MTL::IndexTypeUInt32);
    geomDesc->setTriangleCount(_rtIndexCount / 3);

    auto* accelDesc = MTL::PrimitiveAccelerationStructureDescriptor::alloc()->init();
    accelDesc->setGeometryDescriptors(NS::Array::array((NS::Object*)geomDesc));
    // Flag the BLAS as refit-capable at first build so later frames can
    // use refitAccelerationStructure instead of a full rebuild.
    accelDesc->setUsage(MTL::AccelerationStructureUsageRefit);
    MTL::AccelerationStructureSizes sizes = _pDevice->accelerationStructureSizes(accelDesc);
    if (!canRefit) {
        _pRTBLAS = _pDevice->newAccelerationStructure(sizes.accelerationStructureSize);
    }
    auto* scratchBuffer = _pDevice->newBuffer(
        canRefit ? sizes.refitScratchBufferSize : sizes.buildScratchBufferSize,
        MTL::ResourceStorageModePrivate);

    // Async BLAS build / refit on a dedicated command buffer with GPU
    // event sync. Refit reuses the existing BVH topology and only
    // updates primitive AABBs, which on Apple Silicon is 3-5× faster
    // than a full rebuild.
    auto* blasCmdBuf = _pCommandQueue->commandBuffer();
    blasCmdBuf->setLabel(NS::String::string(canRefit ? "BLAS Refit" : "BLAS Build",
                                            NS::UTF8StringEncoding));
    auto* accelEnc = blasCmdBuf->accelerationStructureCommandEncoder();
    if (canRefit) {
        accelEnc->refitAccelerationStructure(_pRTBLAS, accelDesc, _pRTBLAS, scratchBuffer, 0);
    } else {
        accelEnc->buildAccelerationStructure(_pRTBLAS, accelDesc, scratchBuffer, 0);
    }
    accelEnc->endEncoding();
    _lastBLASTriCount = (uint32_t)(frameIndices.size() / 3);
    
    // Signal shared event when BLAS build completes — RT compute will wait
    // on this. Event is owned at module scope (see top of file) so
    // VID_Shutdown can release it; previously the function-static leaked.
    if (!_blasEvent) _blasEvent = _pDevice->newSharedEvent();
    _blasEventValue++;
    ((void (*)(id, SEL, id, uint64_t))objc_msgSend)((id)blasCmdBuf,
        sel_registerName("encodeSignalEvent:value:"), (id)_blasEvent, _blasEventValue);
    blasCmdBuf->commit(); // Non-blocking! GPU works in parallel
    
    // Store event info for RT compute to wait on
    _rtBLASEvent = _blasEvent;
    _rtBLASEventValue = _blasEventValue;
    
    scratchBuffer->release(); accelDesc->release(); geomDesc->release();
    _pTriTexInfoBuffer = _pDevice->newBuffer(frameTriTexInfos.data(), frameTriTexInfos.size() * sizeof(TriTexInfo), MTL::ResourceStorageModeShared);
    if (_numActiveLights > 0)
        _pDynLightBuffer = _pDevice->newBuffer(gpuLights, _numActiveLights * sizeof(GPUDynLight), MTL::ResourceStorageModeShared);
    else
        _pDynLightBuffer = nullptr;

    // === Phase 7: Build the IAS that the RT shader reads ===
    //
    // Two paths:
    //
    //   Default (r_rt_split_blas == 0): wrap the unified BLAS in a
    //   1-instance IAS. offsets = [0]. Semantically equivalent to the
    //   original direct-BLAS dispatch with one extra BVH traversal
    //   level.
    //
    //   Split  (r_rt_split_blas == 1): a cached world BLAS + a
    //   per-frame entity BLAS become two instances in the IAS. offsets
    //   = [0, _worldTriCount] so the shader can land the right
    //   TriTexInfo for either instance's primitive_id. The world BLAS
    //   is rebuilt only on map change (detected by triggering the
    //   _worldGeomBuilt flag above).

    if (_pRTInstancedAS) { _pRTInstancedAS->release(); _pRTInstancedAS = nullptr; }
    if (_pInstanceDescBuffer) { _pInstanceDescBuffer->release(); _pInstanceDescBuffer = nullptr; }

    if (!_pInstanceOffsetsBuffer) {
        _pInstanceOffsetsBuffer = _pDevice->newBuffer(sizeof(uint32_t) * 2, MTL::ResourceStorageModeShared);
    }

    cvar_t *splitCvar = Cvar_FindVar((char*)"r_rt_split_blas");
    bool wantSplit = (splitCvar && splitCvar->value != 0.0f);

    // Identity transform reused for both single- and multi-instance
    // IAS builds.
    auto makeIdentityInstance = [](uint32_t blasIndex) {
        MTL::AccelerationStructureInstanceDescriptor inst = {};
        inst.transformationMatrix.columns[0] = MTL::PackedFloat3(1.0f, 0.0f, 0.0f);
        inst.transformationMatrix.columns[1] = MTL::PackedFloat3(0.0f, 1.0f, 0.0f);
        inst.transformationMatrix.columns[2] = MTL::PackedFloat3(0.0f, 0.0f, 1.0f);
        inst.transformationMatrix.columns[3] = MTL::PackedFloat3(0.0f, 0.0f, 0.0f);
        inst.options = MTL::AccelerationStructureInstanceOptionOpaque;
        inst.mask = 0xFF;
        inst.intersectionFunctionTableOffset = 0;
        inst.accelerationStructureIndex = blasIndex;
        return inst;
    };

    auto buildIAS = [&](NS::Array* blasArray, const void* descs, int descCount) {
        _pInstanceDescBuffer = _pDevice->newBuffer(
            descs,
            descCount * sizeof(MTL::AccelerationStructureInstanceDescriptor),
            MTL::ResourceStorageModeShared);

        auto* iasDesc = MTL::InstanceAccelerationStructureDescriptor::alloc()->init();
        iasDesc->setInstancedAccelerationStructures(blasArray);
        iasDesc->setInstanceCount(descCount);
        iasDesc->setInstanceDescriptorBuffer(_pInstanceDescBuffer);
        iasDesc->setInstanceDescriptorStride(sizeof(MTL::AccelerationStructureInstanceDescriptor));

        MTL::AccelerationStructureSizes iasSizes = _pDevice->accelerationStructureSizes(iasDesc);
        _pRTInstancedAS = _pDevice->newAccelerationStructure(iasSizes.accelerationStructureSize);
        auto* iasScratch = _pDevice->newBuffer(iasSizes.buildScratchBufferSize, MTL::ResourceStorageModePrivate);

        auto* iasCmdBuf = _pCommandQueue->commandBuffer();
        iasCmdBuf->setLabel(NS::String::string("IAS Build", NS::UTF8StringEncoding));
        auto* iasEnc = iasCmdBuf->accelerationStructureCommandEncoder();
        iasEnc->buildAccelerationStructure(_pRTInstancedAS, iasDesc, iasScratch, 0);
        iasEnc->endEncoding();
        iasCmdBuf->commit();
        iasCmdBuf->waitUntilCompleted();

        iasScratch->release();
        iasDesc->release();
    };

    if (wantSplit && !_worldVertices.empty() && frameVertices.size() > _worldVertices.size()) {
        // --- Split path ---
        // World BLAS — cached; rebuild only when the world geometry was
        // re-collected (map change).
        uint32_t worldTris = (uint32_t)(_worldIndices.size() / 3);
        if (!_pWorldBLAS) {
            if (_pWorldBLASVBuffer) _pWorldBLASVBuffer->release();
            if (_pWorldBLASIBuffer) _pWorldBLASIBuffer->release();
            _pWorldBLASVBuffer = _pDevice->newBuffer(_worldVertices.data(), _worldVertices.size() * sizeof(RTVertex), MTL::ResourceStorageModeShared);
            _pWorldBLASIBuffer = _pDevice->newBuffer(_worldIndices.data(),  _worldIndices.size()  * sizeof(uint32_t), MTL::ResourceStorageModeShared);

            auto* wGeom = MTL::AccelerationStructureTriangleGeometryDescriptor::alloc()->init();
            wGeom->setVertexBuffer(_pWorldBLASVBuffer); wGeom->setVertexStride(sizeof(RTVertex));
            wGeom->setIndexBuffer(_pWorldBLASIBuffer);   wGeom->setIndexType(MTL::IndexTypeUInt32);
            wGeom->setTriangleCount(worldTris);

            auto* wDesc = MTL::PrimitiveAccelerationStructureDescriptor::alloc()->init();
            wDesc->setGeometryDescriptors(NS::Array::array((NS::Object*)wGeom));
            MTL::AccelerationStructureSizes wSizes = _pDevice->accelerationStructureSizes(wDesc);
            _pWorldBLAS = _pDevice->newAccelerationStructure(wSizes.accelerationStructureSize);
            auto* wScratch = _pDevice->newBuffer(wSizes.buildScratchBufferSize, MTL::ResourceStorageModePrivate);

            auto* wCmd = _pCommandQueue->commandBuffer();
            wCmd->setLabel(NS::String::string("World BLAS Build (split)", NS::UTF8StringEncoding));
            auto* wEnc = wCmd->accelerationStructureCommandEncoder();
            wEnc->buildAccelerationStructure(_pWorldBLAS, wDesc, wScratch, 0);
            wEnc->endEncoding();
            wCmd->commit();
            wCmd->waitUntilCompleted();
            wScratch->release(); wDesc->release(); wGeom->release();
            _worldTriCount = worldTris;
        }

        // Entity BLAS — per-frame. Re-base entity indices so they point
        // into a dense entity-only vertex buffer.
        size_t worldV = _worldVertices.size();
        std::vector<RTVertex> entVerts(frameVertices.begin() + worldV, frameVertices.end());
        std::vector<uint32_t> entIdx;
        entIdx.reserve(frameIndices.size() - _worldIndices.size());
        for (size_t i = _worldIndices.size(); i < frameIndices.size(); i++) {
            entIdx.push_back(frameIndices[i] - (uint32_t)worldV);
        }

        if (_pEntityBLAS)        { _pEntityBLAS->release();        _pEntityBLAS = nullptr; }
        if (_pEntityBLASVBuffer) { _pEntityBLASVBuffer->release(); _pEntityBLASVBuffer = nullptr; }
        if (_pEntityBLASIBuffer) { _pEntityBLASIBuffer->release(); _pEntityBLASIBuffer = nullptr; }

        if (entIdx.size() >= 3) {
            _pEntityBLASVBuffer = _pDevice->newBuffer(entVerts.data(), entVerts.size() * sizeof(RTVertex), MTL::ResourceStorageModeShared);
            _pEntityBLASIBuffer = _pDevice->newBuffer(entIdx.data(),    entIdx.size()    * sizeof(uint32_t), MTL::ResourceStorageModeShared);

            auto* eGeom = MTL::AccelerationStructureTriangleGeometryDescriptor::alloc()->init();
            eGeom->setVertexBuffer(_pEntityBLASVBuffer); eGeom->setVertexStride(sizeof(RTVertex));
            eGeom->setIndexBuffer(_pEntityBLASIBuffer);  eGeom->setIndexType(MTL::IndexTypeUInt32);
            eGeom->setTriangleCount((uint32_t)(entIdx.size() / 3));

            auto* eDesc = MTL::PrimitiveAccelerationStructureDescriptor::alloc()->init();
            eDesc->setGeometryDescriptors(NS::Array::array((NS::Object*)eGeom));
            MTL::AccelerationStructureSizes eSizes = _pDevice->accelerationStructureSizes(eDesc);
            _pEntityBLAS = _pDevice->newAccelerationStructure(eSizes.accelerationStructureSize);
            auto* eScratch = _pDevice->newBuffer(eSizes.buildScratchBufferSize, MTL::ResourceStorageModePrivate);

            auto* eCmd = _pCommandQueue->commandBuffer();
            eCmd->setLabel(NS::String::string("Entity BLAS Build (split)", NS::UTF8StringEncoding));
            auto* eEnc = eCmd->accelerationStructureCommandEncoder();
            eEnc->buildAccelerationStructure(_pEntityBLAS, eDesc, eScratch, 0);
            eEnc->endEncoding();
            eCmd->commit();
            eCmd->waitUntilCompleted();
            eScratch->release(); eDesc->release(); eGeom->release();
        }

        // Populate offsets [0, worldTriCount] so the entity instance's
        // primitive_ids rebase into the triTexInfos tail.
        uint32_t offsets[2] = { 0u, _worldTriCount };
        memcpy(_pInstanceOffsetsBuffer->contents(), offsets, sizeof(offsets));

        MTL::AccelerationStructureInstanceDescriptor descs[2];
        descs[0] = makeIdentityInstance(0); // world BLAS at array index 0
        descs[1] = makeIdentityInstance(1); // entity BLAS at array index 1
        int instanceCount = 2;

        // NS::Array holding the BLAS pointers in the same order as the
        // descriptors' accelerationStructureIndex.
        const NS::Object* blasObjects[2] = {
            (const NS::Object*)_pWorldBLAS,
            (const NS::Object*)(_pEntityBLAS ? _pEntityBLAS : _pWorldBLAS)
        };
        if (!_pEntityBLAS) {
            // No entity geometry this frame — collapse to 1 instance.
            descs[0].accelerationStructureIndex = 0;
            instanceCount = 1;
            offsets[1] = 0;
            memcpy(_pInstanceOffsetsBuffer->contents(), offsets, sizeof(offsets));
        }
        NS::Array* blasArray = NS::Array::array(blasObjects, instanceCount);
        buildIAS(blasArray, descs, instanceCount);
    } else {
        // --- Unified path (default) ---
        // Release the split-path caches so a mode switch doesn't leak.
        if (_pWorldBLAS)        { _pWorldBLAS->release();        _pWorldBLAS = nullptr; }
        if (_pEntityBLAS)       { _pEntityBLAS->release();       _pEntityBLAS = nullptr; }
        if (_pWorldBLASVBuffer) { _pWorldBLASVBuffer->release(); _pWorldBLASVBuffer = nullptr; }
        if (_pWorldBLASIBuffer) { _pWorldBLASIBuffer->release(); _pWorldBLASIBuffer = nullptr; }
        if (_pEntityBLASVBuffer){ _pEntityBLASVBuffer->release();_pEntityBLASVBuffer = nullptr; }
        if (_pEntityBLASIBuffer){ _pEntityBLASIBuffer->release();_pEntityBLASIBuffer = nullptr; }

        uint32_t offsets[2] = { 0u, 0u };
        memcpy(_pInstanceOffsetsBuffer->contents(), offsets, sizeof(offsets));

        MTL::AccelerationStructureInstanceDescriptor desc = makeIdentityInstance(0);
        NS::Array* blasArray = NS::Array::array((NS::Object*)_pRTBLAS);
        buildIAS(blasArray, &desc, 1);
    }
}

static void BuildPipeline() {
    using NS::StringEncoding::UTF8StringEncoding;
    const char* shaderSource = R"(
        #include <metal_stdlib>
        using namespace metal;
        struct VertexOut { float4 position [[position]]; float2 texCoord; };
        vertex VertexOut vertexMain(uint vertexID [[vertex_id]]) {
            float2 texCoords[] = { float2(0,0), float2(2,0), float2(0,2) };
            VertexOut out;
            out.position = float4(texCoords[vertexID] * 2.0 - 1.0, 0.0, 1.0);
            out.position.y = -out.position.y;
            out.texCoord = texCoords[vertexID];
            return out;
        }
        // --- Helper: ACES filmic tonemapping ---
        float3 ACESFilm(float3 x) {
            float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
            return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
        }
        
        // --- Helper: hash for film grain ---
        float hash(float2 p) {
            float3 p3 = fract(float3(p.xyx) * 0.1031);
            p3 += dot(p3, p3.yzx + 33.33);
            return fract((p3.x + p3.y) * p3.z);
        }
        
        // --- Helper: get unified color (Software Palette or RT Overlay) ---
        float3 getPixelColor(float2 uv, texture2d<uint> indexTex, texture2d<float> paletteTex, texture2d<float> rtTex) {
            int iw = indexTex.get_width(), ih = indexTex.get_height();
            int2 sc = int2(uv.x * (float)iw, uv.y * (float)ih);
            sc = clamp(sc, int2(0), int2(iw - 1, ih - 1));
            uint index = indexTex.read(uint2(sc)).r;
            if (index == 254) {
                // RTX overlay or chroma key
                constexpr sampler lin(filter::linear);
                return rtTex.sample(lin, uv).rgb;
            } else {
                return paletteTex.read(uint2(index, 0)).rgb;
            }
        }

        // Function constants for pipeline specialization. When a constant
        // is false at pipeline-build time the compiler dead-code-eliminates
        // the corresponding branch entirely. We keep the per-frame runtime
        // uniforms too so the 32-variant cache (2^5) isn't strictly needed
        // — the fallback default pipeline binds all constants true and
        // falls back to runtime gating.
        constant bool fc_ssao        [[function_constant(0)]];
        constant bool fc_crt         [[function_constant(1)]];
        constant bool fc_liquidglass [[function_constant(2)]];
        constant bool fc_chroma      [[function_constant(3)]];
        constant bool fc_hc_hud      [[function_constant(4)]];

        // Packed uniforms: screenBlend + time + flags + resolution.
        // Explicit padding keeps 16-byte alignment on every float4-sized
        // row so the Metal validation layer doesn't complain on stricter
        // drivers. Field order here must match the matching C++ struct
        // below where we `setBytes` this layout.
        struct PostFXUniforms {
            float4 screenBlend;      // 0
            float  time;             // 16
            float  underwater;       // 20 — 1.0 = in water/slime/lava
            float  crt_mode;         // 24
            float  liquid_glass;     // 28
            float2 resolution;       // 32
            float  ssao_enabled;     // 40
            float  edr_enabled;      // 44
            float  chromatic_aberration; // 48 — 0.0 off, >0 = aberration strength
            float  high_contrast_hud;// 52 — 0.0 off, 1.0 boost HUD saturation
            float  hud_band_y;       // 56 — top of HUD band in UV (aspect-aware)
            float  _pad0;            // 60 — round up to 64
        };

        fragment float4 fragmentMain(VertexOut in [[stage_in]],
                                   texture2d<uint> indexTex [[texture(0)]],
                                   texture2d<float> paletteTex [[texture(1)]],
                                   texture2d<float> rtTex [[texture(2)]],
                                   texture2d<float> depthTex [[texture(3)]],
                                   constant PostFXUniforms& u [[buffer(0)]]) {
            if (in.texCoord.x > 1.0 || in.texCoord.y > 1.0) discard_fragment();
            
            // 0. Underwater warp — sine-wave UV distortion (replaces D_WarpScreen)
            float2 uv = in.texCoord;
            if (u.underwater > 0.5) {
                float t = u.time;
                float warpX = sin(uv.y * 20.0 + t * 4.0) * 0.005;
                float warpY = cos(uv.x * 20.0 + t * 3.5) * 0.005;
                // Second octave for organic feel
                warpX += sin(uv.y * 40.0 - t * 2.5) * 0.002;
                warpY += cos(uv.x * 35.0 + t * 3.0) * 0.002;
                uv += float2(warpX, warpY);
                uv = clamp(uv, 0.001, 0.999);
            }
            
            // 1. Get base color
            float3 color = getPixelColor(uv, indexTex, paletteTex, rtTex);
            
            // 2. High-Quality Bloom & Adaptive Sharpen
            float3 bloomAccum = float3(0);
            float bloomTotal = 0.0;
            float2 texelSize = float2(1.0 / indexTex.get_width(), 1.0 / indexTex.get_height());
            const int2 offsets[5] = { int2(0,0), int2(1,0), int2(-1,0), int2(0,1), int2(0,-1) };
            const float weights[5] = { 0.382928, 0.241732, 0.241732, 0.241732, 0.241732 };
            
            float3 blurAccum = float3(0);
            for(int i = 0; i < 5; i++) {
                float2 uv = in.texCoord + float2(offsets[i]) * texelSize * 1.5;
                float3 s = getPixelColor(uv, indexTex, paletteTex, rtTex);
                blurAccum += s * weights[i];
                float lum = dot(s, float3(0.2126, 0.7152, 0.0722));
                // Threshold is applied pre-ACES; after the filmic curve runs
                // later, anything above ~0.55 linear ends up visibly bright.
                // 0.75 was too conservative — nothing bloomed.
                float bright = max(lum - 0.55, 0.0);
                bloomAccum += s * bright * weights[i];
                bloomTotal += weights[i];
            }
            
            color += (bloomAccum / bloomTotal) * 0.15; // Dialed back bloom
            
            // Unsharp Mask
            float3 detail = color - (blurAccum / bloomTotal);
            color = max(color + detail * 0.65, float3(0.0)); // Crispen edges and clamp to 0
            
            // 3. ACES filmic tonemapping
            color = ACESFilm(color * 1.15); // Slight exposure boost before film curve
            
            // 4. Color Grading (Contrast & Saturation)
            float lum = dot(color, float3(0.2126, 0.7152, 0.0722));
            color = mix(float3(lum), color, 1.15); // Gentle saturation boost
            color = mix(color, color * color * (3.0 - 2.0 * color), 0.2); // Subtle S-curve for contrast
            
            // 4.2. Cinematic Depth of Field (DoF)
            int iw = indexTex.get_width(), ih = indexTex.get_height();
            int2 sc = int2(in.texCoord.x * (float)iw, in.texCoord.y * (float)ih);
            uint uiIndex = indexTex.read(uint2(clamp(sc, int2(0), int2(iw - 1, ih - 1)))).r;
            if (uiIndex == 254) {
                // Apply DoF to 3D world pixels only
                constexpr sampler depthSamp(filter::linear);
                float viewDepth = depthTex.sample(depthSamp, in.texCoord).r;
                // Crosshair autofocus with 5-tap weighted average so a single
                // sky pixel behind the crosshair doesn't push focus to
                // infinity. Center plus four small offsets inside the
                // viewmodel's likely pixel range.
                float focusDepth = depthTex.sample(depthSamp, float2(0.5, 0.5)).r * 0.5;
                focusDepth += depthTex.sample(depthSamp, float2(0.48, 0.50)).r * 0.125;
                focusDepth += depthTex.sample(depthSamp, float2(0.52, 0.50)).r * 0.125;
                focusDepth += depthTex.sample(depthSamp, float2(0.50, 0.48)).r * 0.125;
                focusDepth += depthTex.sample(depthSamp, float2(0.50, 0.52)).r * 0.125;
                
                // Do not autofocus on sky (depth 00 or 1.0? Raytracer outputs depth. Sky is usually far).
                // Actually, depth is linear distance from RT.
                float depthDiff = abs(viewDepth - focusDepth);
                float blurAmt = smoothstep(50.0, 400.0, depthDiff); // Tuning blur range units
                if (blurAmt > 0.05) {
                    float3 dofAccum = float3(0);
                    float dofTotal = 0;
                    // Optimized 4-tap Bokeh
                    for(int i=0; i<4; i++) {
                        float angle = i * 1.570796;
                        float2 dofUV = in.texCoord + float2(cos(angle), sin(angle)) * texelSize * blurAmt * 4.0;
                        dofAccum += getPixelColor(dofUV, indexTex, paletteTex, rtTex);
                        dofTotal += 1.0;
                    }
                    color = mix(color, dofAccum / dofTotal, blurAmt * 0.75); // Blend Bokeh
                }
            }
            
            // 4.5. Volumetric God Rays removed - caused radial artifact banding around localized light fixtures
            
            
            // 5. Cinematic Vignette
            float2 vigUV = in.texCoord - 0.5;
            float vig = 1.0 - dot(vigUV, vigUV) * 0.9;
            vig = saturate(vig * vig);
            color *= mix(0.65, 1.0, vig);
            
            // 5.5. SSAO — Screen-Space Ambient Occlusion from RT depth
            if (fc_ssao && u.ssao_enabled > 0.5) {
                constexpr sampler ssaoSamp(filter::linear);
                float centerDepth = depthTex.sample(ssaoSamp, in.texCoord).r;
                // RT shader writes raw world-unit distance (up to ~100000);
                // the old 9000 filter excluded most outdoor geometry from
                // SSAO entirely.
                if (centerDepth > 0.01 && centerDepth < 90000.0) {
                    float occlusion = 0.0;
                    float radius = 0.015; // screen-space radius
                    // 8-sample hemisphere kernel with hash-based per-pixel rotation
                    float hashVal = fract(sin(dot(in.texCoord * u.resolution, float2(12.9898, 78.233))) * 43758.5453);
                    float rotAngle = hashVal * 6.28318;
                    float cosR = cos(rotAngle), sinR = sin(rotAngle);
                    // Unrolled 8-sample kernel
                    float2 ssaoOffsets[8];
                    ssaoOffsets[0] = float2( 0.35, 0.15); ssaoOffsets[1] = float2(-0.20, 0.40);
                    ssaoOffsets[2] = float2( 0.50,-0.25); ssaoOffsets[3] = float2(-0.10,-0.45);
                    ssaoOffsets[4] = float2( 0.15, 0.50); ssaoOffsets[5] = float2(-0.45, 0.10);
                    ssaoOffsets[6] = float2( 0.25,-0.40); ssaoOffsets[7] = float2(-0.30,-0.20);
                    for (int si = 0; si < 8; si++) {
                        float2 k = ssaoOffsets[si];
                        // Rotate sample point
                        float2 rotK = float2(k.x * cosR - k.y * sinR, k.x * sinR + k.y * cosR);
                        float2 sampleUV = in.texCoord + rotK * radius;
                        sampleUV = clamp(sampleUV, 0.001, 0.999);
                        float sampleDepth = depthTex.sample(ssaoSamp, sampleUV).r;
                        // Range-checked occlusion
                        float rangeCheck = smoothstep(0.0, 1.0, radius * 200.0 / max(abs(centerDepth - sampleDepth), 0.001));
                        occlusion += (sampleDepth < centerDepth - 0.5 ? 1.0 : 0.0) * rangeCheck;
                    }
                    occlusion = 1.0 - (occlusion / 8.0) * 0.6; // 60% max darkening
                    color *= occlusion;
                }
            }
            
            // 7. Screen Blends (damage flashes, underwater, powerups)
            if (u.screenBlend.w > 0.001) {
                color = mix(color, u.screenBlend.rgb, u.screenBlend.w);
            }
            
            // 8. CRT Scanline Filter — retro monitor emulation
            if (fc_crt && u.crt_mode > 0.5) {
                float2 crtUV = in.texCoord;
                // Barrel distortion (subtle CRT curvature)
                float2 dc = crtUV - 0.5;
                float r2 = dot(dc, dc);
                crtUV = crtUV + dc * r2 * 0.08;
                
                // Scanlines — darken every other physical pixel row
                float scanline = sin(crtUV.y * u.resolution.y * 3.14159) * 0.5 + 0.5;
                scanline = pow(scanline, 1.5) * 0.15 + 0.85; // 15% darkening
                color *= scanline;
                
                // Phosphor sub-pixel tint (RGB columns)
                int col = int(crtUV.x * u.resolution.x) % 3;
                float3 phosphor = float3(col == 0 ? 1.2 : 0.9,
                                         col == 1 ? 1.2 : 0.9,
                                         col == 2 ? 1.2 : 0.9);
                color *= phosphor;
                
                // Edge vignette glow (warm CRT border)
                float crtVig = 1.0 - smoothstep(0.4, 0.52, length(dc));
                color *= crtVig;
                
                // Slight bloom on bright pixels for phosphor glow
                float lum = dot(color, float3(0.2126, 0.7152, 0.0722));
                if (lum > 0.7) color += (color - 0.7) * 0.3;
            }
            
            // 9. Liquid Glass HUD — frosted glass overlay on status bar.
            // HUD band Y is aspect-aware (wider display → thinner band) so
            // the ribbon doesn't swallow the whole screen on 21:9 / 32:9.
            if (fc_liquidglass && u.liquid_glass > 0.5) {
                float2 hudUV = in.texCoord;
                float bandTop = u.hud_band_y > 0.01 ? u.hud_band_y : 0.82;
                float hudMask = smoothstep(bandTop, bandTop + 0.03, hudUV.y);
                if (hudMask > 0.01) {
                    // Frosted blur (5-tap weighted)
                    float2 texelSz = 1.0 / u.resolution;
                    float3 blurred = color * 0.375;
                    blurred += getPixelColor(hudUV + float2( texelSz.x * 2.0, 0), indexTex, paletteTex, rtTex) * 0.15625;
                    blurred += getPixelColor(hudUV + float2(-texelSz.x * 2.0, 0), indexTex, paletteTex, rtTex) * 0.15625;
                    blurred += getPixelColor(hudUV + float2(0,  texelSz.y * 2.0), indexTex, paletteTex, rtTex) * 0.15625;
                    blurred += getPixelColor(hudUV + float2(0, -texelSz.y * 2.0), indexTex, paletteTex, rtTex) * 0.15625;
                    
                    // Cool blue-white glass tint
                    float3 glassTint = blurred * float3(0.92, 0.95, 1.08) + float3(0.03, 0.04, 0.06);
                    
                    // Animated specular edge highlight (ribbon of light)
                    float edgeGlow = smoothstep(0.83, 0.855, hudUV.y) * (1.0 - smoothstep(0.855, 0.87, hudUV.y));
                    float ribbon = sin(hudUV.x * 30.0 + u.time * 1.5) * 0.5 + 0.5;
                    glassTint += float3(0.15) * edgeGlow * ribbon;
                    
                    // Chromatic aberration at glass edge
                    float chromaEdge = edgeGlow * 0.003;
                    if (chromaEdge > 0.0001) {
                        glassTint.r = getPixelColor(hudUV + float2(chromaEdge, 0), indexTex, paletteTex, rtTex).r * 0.92 + 0.03;
                        glassTint.b = getPixelColor(hudUV - float2(chromaEdge, 0), indexTex, paletteTex, rtTex).b * 1.08 + 0.06;
                    }
                    
                    color = mix(color, glassTint, hudMask * 0.7);
                }
            }
            
            // 9b. Global Chromatic Aberration — subtle lens fringing. Runs
            // before EDR so the aberration is tone-mapped along with the
            // rest of the color. Strength is gated by user cvar.
            if (fc_chroma && u.chromatic_aberration > 0.5) {
                float2 caCenter = in.texCoord - 0.5;
                float caDist = dot(caCenter, caCenter); // squared — cheap
                float caAmt = 0.002 * caDist * 4.0;     // 0 at center, up to ~0.008 at corners
                float2 caDir = caCenter * caAmt;
                float3 caCol = color;
                caCol.r = getPixelColor(in.texCoord + caDir, indexTex, paletteTex, rtTex).r;
                caCol.b = getPixelColor(in.texCoord - caDir, indexTex, paletteTex, rtTex).b;
                // Re-run the same color grade we applied earlier so R/B
                // samples don't skip the tonemapper.
                float caLum = dot(caCol, float3(0.2126, 0.7152, 0.0722));
                caCol = mix(float3(caLum), caCol, 1.15);
                color = mix(color, caCol, 0.6);
            }

            // 9c. High-Contrast HUD — accessibility. Boosts saturation and
            // contrast on the bottom HUD band only, leaving the 3D world
            // alone. Combines with Liquid Glass (both can be on at once).
            if (fc_hc_hud && u.high_contrast_hud > 0.5) {
                float bandTop = u.hud_band_y > 0.01 ? u.hud_band_y : 0.82;
                float hcMask = smoothstep(bandTop, bandTop + 0.02, in.texCoord.y);
                if (hcMask > 0.01) {
                    float hcLum = dot(color, float3(0.2126, 0.7152, 0.0722));
                    float3 punchy = mix(float3(hcLum), color, 1.6);
                    punchy = clamp(punchy * 1.15, 0.0, 1.0);
                    color = mix(color, punchy, hcMask);
                }
            }

            // 10. EDR — Extended Dynamic Range output for XDR displays
            if (u.edr_enabled > 0.5) {
                // Allow values > 1.0 for HDR headroom on XDR panels
                // Apply a subtle highlight expansion: brightest pixels can reach 2.0
                float peakLum = max(max(color.r, color.g), color.b);
                if (peakLum > 0.8) {
                    float expansion = 1.0 + (peakLum - 0.8) * 2.5; // 0.8→1.0, 1.0→1.5
                    color *= expansion / max(peakLum, 0.001) * peakLum;
                }
                return float4(max(color, float3(0.0)), 1.0);
            }
            
            return float4(saturate(color), 1.0);
        }
    )";
    NS::Error* pError = nullptr;
    auto* pLib = _pDevice->newLibrary(NS::String::string(shaderSource, UTF8StringEncoding), nullptr, &pError);
    if (pError) {
        printf("Metal Shader Compile Error: %s\n", pError->localizedDescription()->utf8String());
        exit(1);
    }
    auto* pVertexFn = pLib->newFunction(NS::String::string("vertexMain", UTF8StringEncoding));
    // All 5 function constants must be bound at pipeline-build time
    // or Metal refuses to compile the fragment. The default pipeline
    // binds them all true so every runtime-gated branch behaves
    // identically to the pre-specialization path. The pipeline cache
    // built below will create additional variants with specific
    // constants set to false for dead-code elimination.
    bool fcTrue = true;
    auto* pDefaultFCV = MTL::FunctionConstantValues::alloc()->init();
    for (int i = 0; i < 5; i++) {
        pDefaultFCV->setConstantValue(&fcTrue, MTL::DataTypeBool, i);
    }
    NS::Error* pFCErr = nullptr;
    auto* pFragFn = pLib->newFunction(NS::String::string("fragmentMain", UTF8StringEncoding),
                                       pDefaultFCV, &pFCErr);
    if (pFCErr) {
        printf("PostFX fragment (default FCV) compile error: %s\n",
               pFCErr->localizedDescription()->utf8String());
    }
    pDefaultFCV->release();
    auto* pDesc = MTL::RenderPipelineDescriptor::alloc()->init();
    pDesc->setVertexFunction(pVertexFn); pDesc->setFragmentFunction(pFragFn);
    pDesc->colorAttachments()->object(0)->setPixelFormat(MTL::PixelFormatBGRA8Unorm);
    
    // Setup MTLBinaryArchive for Zero-Stutter Shader Caching. Cache is
    // stored in the module-level _pShaderArchive so VID_Shutdown can
    // serialize it back to disk — previously the archive was
    // function-local and never written, which meant every launch paid
    // the full JIT cost on first frame.
    NS::Error* pArchiveError = nullptr;
    auto* pArchiveDesc = MTL::BinaryArchiveDescriptor::alloc()->init();
    auto* archiveUrl = NS::URL::fileURLWithPath(NS::String::string("id1/quake_shader_cache.bin", NS::UTF8StringEncoding));
    pArchiveDesc->setUrl(archiveUrl);
    _pShaderArchive = _pDevice->newBinaryArchive(pArchiveDesc, &pArchiveError);
    if (!_pShaderArchive) {
        _pShaderArchive = _pDevice->newBinaryArchive(nullptr, &pArchiveError);
    }
    MTL::BinaryArchive* pArchive = _pShaderArchive;
    
    if (pArchive) {
        NS::Array* archives = NS::Array::array((NS::Object*)pArchive);
        ((void (*)(id, SEL, id))objc_msgSend)((id)pDesc, sel_registerName("setBinaryArchives:"), (id)archives);
    }

    _pPipelineState = _pDevice->newRenderPipelineState(pDesc, &pError);
    if (pArchive && _pPipelineState) {
        ((void (*)(id, SEL, id, id))objc_msgSend)((id)pArchive, sel_registerName("addRenderPipelineFunctionsWithDescriptor:error:"), (id)pDesc, nullptr);
    }
    
    pVertexFn->release(); pFragFn->release();

    if (MQ_GetSettings()->mesh_shaders) {
        std::ifstream ifs("src/macos/MQ_MeshShaders.metal");
        std::string content((std::istreambuf_iterator<char>(ifs)), (std::istreambuf_iterator<char>()));
        if (!content.empty()) {
            NS::String* meshSourceStr = NS::String::string(content.c_str(), NS::UTF8StringEncoding);
            auto* pMeshLib = _pDevice->newLibrary(meshSourceStr, nullptr, &pError);
            if (pError) {
                printf("Mesh Shader Compile Error: %s\n", pError->localizedDescription()->utf8String());
            } else {
                auto* pObjFn = pMeshLib->newFunction(NS::String::string("bspObjectShader", NS::UTF8StringEncoding));
                auto* pMeshFn = pMeshLib->newFunction(NS::String::string("bspMeshShader", NS::UTF8StringEncoding));
                auto* pMeshFragFn = pMeshLib->newFunction(NS::String::string("bspMeshFragment", NS::UTF8StringEncoding));
                
                auto* pMeshDesc = MTL::MeshRenderPipelineDescriptor::alloc()->init();
                pMeshDesc->setObjectFunction(pObjFn);
                pMeshDesc->setMeshFunction(pMeshFn);
                pMeshDesc->setFragmentFunction(pMeshFragFn);
                pMeshDesc->colorAttachments()->object(0)->setPixelFormat(MTL::PixelFormatBGRA8Unorm);
                pMeshDesc->setDepthAttachmentPixelFormat(MTL::PixelFormatR32Float); // If used
                
                if (pArchive) {
                    NS::Array* archives = NS::Array::array((NS::Object*)pArchive);
                    ((void (*)(id, SEL, id))objc_msgSend)((id)pMeshDesc, sel_registerName("setBinaryArchives:"), (id)archives);
                }
                
                _pMeshPipelineState = _pDevice->newRenderPipelineState(pMeshDesc, MTL::PipelineOptionNone, nullptr, &pError);
                if (pError) {
                    printf("Mesh Pipeline Creation Error: %s\n", pError->localizedDescription()->utf8String());
                } else {
                    printf("Mesh Pipeline successfully created!\n");
                    if (pArchive) {
                        // The mesh pipeline descriptor might not be supported by addRenderPipelineFunctions directly in some headers
                        // We skip explicit addition if not supported since the array binding implicitly caches in macOS 14+
                    }
                }
                
                pObjFn->release(); pMeshFn->release(); pMeshFragFn->release();
                pMeshDesc->release();
                pMeshLib->release();
            }
        }
    }
    
    // Serialize the archive back to disk to ensure zero-stutter on next launch
    if (pArchive) {
        ((void (*)(id, SEL, id, id))objc_msgSend)((id)pArchive, sel_registerName("serializeToURL:error:"), (id)archiveUrl, nullptr);
        pArchive->release();
    }

    const char* rtShaderSource = R"(
        #include <metal_stdlib>
        using namespace metal;
        using namespace metal::raytracing;

        struct RTVertex { float x, y, z, u, v; };
        struct TriTexInfo {
            float atlas_u, atlas_v;
            float atlas_w, atlas_h;
            float tex_w, tex_h;
            float pad0, pad1;
        };
        struct GPUDynLight { float x, y, z, radius; };

        float3 getPos(device const RTVertex* v, uint i) { return float3(v[i].x, v[i].y, v[i].z); }
        float2 getUV(device const RTVertex* v, uint i) { return float2(v[i].u, v[i].v); }

        float3 getFaceNormal(device const RTVertex* verts, device const uint* indices, uint primId) {
            float3 v0 = getPos(verts, indices[primId*3]);
            float3 v1 = getPos(verts, indices[primId*3+1]);
            float3 v2 = getPos(verts, indices[primId*3+2]);
            return normalize(cross(v1 - v0, v2 - v0));
        }

        // Hash function for procedural effects
        float hash(float2 p) {
            return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
        }

        // Argument buffer — wraps the 6 RT device pointers into one bind.
        // IDs 0..5 correspond to the previous per-slot positional
        // parameters (vertices was buffer 5, indices 6, etc). Moving to
        // an argument buffer halves the setBuffer call count per RT
        // dispatch and enables the driver to page the backing store once
        // via the useResource annotations rather than on every bind.
        struct RTArgs {
            device const RTVertex*    vertices        [[id(0)]];
            device const uint*        indices         [[id(1)]];
            device const TriTexInfo*  triTexInfos     [[id(2)]];
            device const GPUDynLight* dynLights       [[id(3)]];
            device const uint*        instanceOffsets [[id(4)]];
            device const uint*        emissiveTris    [[id(5)]];
        };

        kernel void raytraceMain(uint2 tid [[thread_position_in_grid]],
            texture2d<float, access::write> outTexture [[texture(0)]],
            texture2d<float, access::read> atlasTexture [[texture(1)]],
            instance_acceleration_structure scene [[buffer(0)]],
            constant float4& camOrigin [[buffer(1)]],
            constant float4& camForward [[buffer(2)]],
            constant float4& camRight [[buffer(3)]],
            constant float4& camUp [[buffer(4)]],
            // Single argument buffer replaces the 6 device-pointer
            // positional params that used to live at buffers 5/6/7/8/17/18.
            constant const RTArgs& rtArgs [[buffer(5)]],
            constant int& numLights [[buffer(9)]],
            constant float& time [[buffer(10)]],
            texture2d<float, access::write> depthTexture [[texture(2)]],
            texture2d<float, access::write> motionTexture [[texture(3)]],
            constant float4& prevCamOrigin [[buffer(11)]],
            constant float4& prevCamForward [[buffer(12)]],
            constant float4& prevCamRight [[buffer(13)]],
            constant float4& prevCamUp [[buffer(14)]],
            constant int&    rtQuality [[buffer(15)]],
            constant int&    underwaterFlag [[buffer(16)]],
            constant int&    emissiveCount [[buffer(19)]],
            constant int&    useReSTIR     [[buffer(20)]])
        {
            // Local aliases so the existing shader body keeps reading
            // `vertices[i]` etc. Compiled by the optimizer into direct
            // loads through the argument buffer — no runtime cost.
            device const RTVertex*    vertices        = rtArgs.vertices;
            device const uint*        indices         = rtArgs.indices;
            device const TriTexInfo*  triTexInfos     = rtArgs.triTexInfos;
            device const GPUDynLight* dynLights       = rtArgs.dynLights;
            device const uint*        instanceOffsets = rtArgs.instanceOffsets;
            device const uint*        emissiveTris    = rtArgs.emissiveTris;
            if (tid.x >= outTexture.get_width() || tid.y >= outTexture.get_height()) return;
            float2 uv = (float2(tid) / float2(outTexture.get_width(), outTexture.get_height())) * 2.0 - 1.0;
            uv.y = -uv.y; uv.x *= (float)outTexture.get_width() / (float)outTexture.get_height();

            ray r;
            r.origin = camOrigin.xyz;
            r.direction = normalize(camForward.xyz + uv.x * camRight.xyz + uv.y * camUp.xyz);
            r.min_distance = 0.1;
            r.max_distance = 100000.0;

            // Instance-AS intersector: `instancing` tag makes
            // result.instance_id valid and keeps primitive_id local to
            // the hit BLAS (the behavior we rely on with the offset
            // buffer). Without this tag hits come back with undefined
            // instance_id and the shader renders the world black.
            intersector<triangle_data, instancing> isect;
            isect.assume_geometry_type(geometry_type::triangle);
            isect.force_opacity(forced_opacity::opaque);
            auto result = isect.intersect(r, scene);

            if (result.type != intersection_type::triangle) {
                // Atmospheric sky with subtle gradient
                float t = saturate(r.direction.z * 1.2 + 0.5);
                float3 skyLow = float3(0.45, 0.35, 0.28);
                float3 skyHigh = float3(0.22, 0.30, 0.52);
                float3 sky = mix(skyLow, skyHigh, t);
                // Add subtle cloud noise
                float cn = hash(r.direction.xy * 50.0) * 0.03;
                sky += cn;
                outTexture.write(float4(sky, 1.0), tid);
                depthTexture.write(float4(1.0, 0, 0, 0), tid);   // Max depth for sky
                motionTexture.write(float4(0, 0, 0, 0), tid);     // No motion for sky
                return;
            }

            uint primId = result.primitive_id;
            float dist = result.distance;
            float3 hitPos = r.origin + r.direction * dist;
            float3 N = getFaceNormal(vertices, indices, primId);
            if (dot(N, r.direction) > 0.0) N = -N;

            // === Texture sampling ===
            float2 bary = result.triangle_barycentric_coord;
            float bw = 1.0 - bary.x - bary.y;
            uint i0 = indices[primId*3], i1 = indices[primId*3+1], i2 = indices[primId*3+2];
            float2 texUV = getUV(vertices, i0) * bw + getUV(vertices, i1) * bary.x + getUV(vertices, i2) * bary.y;

            // Apply per-instance metadata offset. instance_id is 0 for the
            // default unified-BLAS path (so offset is 0 and primId is used
            // directly), 0 or 1 for the split path where entity primitives
            // get rebased past the world triangle count.
            uint primIdGlobal = instanceOffsets[result.instance_id] + primId;
            TriTexInfo tti = triTexInfos[primIdGlobal];
            float3 baseColor;
            
            if (tti.atlas_w < 0.0 || tti.tex_w < 1.0 || tti.tex_h < 1.0) {
                // Entity/brush surface without atlas skin
                float nHash = abs(dot(N, float3(0.3, 0.5, 0.7)));
                baseColor = mix(float3(0.55, 0.42, 0.32), float3(0.48, 0.38, 0.28), nHash);
            } else {
                // Sample atlas (world textures and entity skins)
                // Wrap UV within texture tile (handle negative correctly)
                float tw = tti.tex_w; float th = tti.tex_h;
                float su = texUV.x - floor(texUV.x / tw) * tw;
                float sv = texUV.y - floor(texUV.y / th) * th;
                // Clamp to valid range
                su = clamp(su, 0.0f, tw - 1.0f);
                sv = clamp(sv, 0.0f, th - 1.0f);
                int atlasW = atlasTexture.get_width();
                int atlasH = atlasTexture.get_height();
                int ax = clamp((int)(tti.atlas_u * (float)atlasW + su), 0, atlasW - 1);
                int ay = clamp((int)(tti.atlas_v * (float)atlasH + sv), 0, atlasH - 1);
                baseColor = atlasTexture.read(uint2(ax, ay)).rgb;
            }

            // === Liquid surface animation ===
            float liquidType = tti.pad1;
            if (liquidType > 0.5) {
                // Multi-octave warping for realistic fluid motion
                float w1 = sin(hitPos.x * 0.04 + time * 1.8) * cos(hitPos.y * 0.03 + time * 1.3);
                float w2 = sin(hitPos.x * 0.08 + hitPos.y * 0.06 + time * 2.5) * 0.5;
                float w3 = sin(hitPos.y * 0.12 + time * 3.2) * cos(hitPos.x * 0.09 - time * 1.1) * 0.25;
                float warp = (w1 + w2 + w3) * 0.3 + 0.5;
                
                // True Ray-Traced Reflection on liquid surface
                float3 liqN = normalize(N + float3(w1, w2, 0) * 0.12);
                float3 reflDir = reflect(r.direction, liqN);
                
                ray reflRay;
                reflRay.origin = hitPos + liqN * 0.1;
                reflRay.direction = reflDir;
                reflRay.min_distance = 0.1;
                reflRay.max_distance = 1000.0;
                auto reflHit = isect.intersect(reflRay, scene);
                
                float3 reflColor = float3(0.05, 0.06, 0.08); // Sky/Dark fallback
                if (reflHit.type == intersection_type::triangle) {
                    uint rPrim = reflHit.primitive_id;
                    uint rPrimGlobal = instanceOffsets[reflHit.instance_id] + rPrim;
                    TriTexInfo rtti = triTexInfos[rPrimGlobal];
                    if (rtti.atlas_w >= 0.0 && rtti.tex_w >= 1.0) {
                        float2 rBary = reflHit.triangle_barycentric_coord;
                        float rBw = 1.0 - rBary.x - rBary.y;
                        uint ri0 = indices[rPrim*3], ri1 = indices[rPrim*3+1], ri2 = indices[rPrim*3+2];
                        float2 rUV = getUV(vertices, ri0)*rBw + getUV(vertices, ri1)*rBary.x + getUV(vertices, ri2)*rBary.y;
                        float rtw = rtti.tex_w, rth = rtti.tex_h;
                        float rsu = rUV.x - floor(rUV.x / rtw) * rtw;
                        float rsv = rUV.y - floor(rUV.y / rth) * rth;
                        rsu = clamp(rsu, 0.0f, rtw - 1.0f);
                        rsv = clamp(rsv, 0.0f, rth - 1.0f);
                        int raw = atlasTexture.get_width(), rah = atlasTexture.get_height();
                        int rax = clamp((int)(rtti.atlas_u*(float)raw+rsu), 0, raw-1);
                        int ray_v = clamp((int)(rtti.atlas_v*(float)rah+rsv), 0, rah-1);
                        reflColor = atlasTexture.read(uint2(rax, ray_v)).rgb;
                    } else {
                        reflColor = float3(0.4);
                    }
                    float rBspLight = max(rtti.pad0, 0.2f);
                    reflColor *= rBspLight * 1.5;
                }
                
                // Use the actual Quake texture as base, apply color tinting + true reflection
                float3 texBase = baseColor;
                
                if (liquidType < 1.5) {
                    // Water — tint + translucent reflection + refraction.
                    // A secondary refracted ray (Snell's law, n=1.33)
                    // samples the underwater geometry, tinted green to
                    // suggest suspended particulates. This is genuinely
                    // see-through now instead of the old mirror-mix.
                    float3 tint = float3(0.4, 0.75, 0.8);
                    float caustic = (sin(hitPos.x * 0.15 + time * 2.0) * sin(hitPos.y * 0.15 + time * 1.7) + 1.0) * 0.08;

                    // Refract through the perturbed surface normal. The
                    // refraction coefficient 1.0/1.33 is air→water;
                    // flipping the sign of N would invert for exit rays.
                    float3 refractDir = refract(r.direction, liqN, 1.0/1.33);
                    float3 refractColor = float3(0.10, 0.18, 0.22); // underwater fog default
                    if (length(refractDir) > 0.01) {
                        ray refractRay;
                        refractRay.origin = hitPos - N * 0.1;
                        refractRay.direction = normalize(refractDir);
                        refractRay.min_distance = 0.1;
                        refractRay.max_distance = 500.0;
                        auto refractHit = isect.intersect(refractRay, scene);
                        if (refractHit.type == intersection_type::triangle) {
                            uint rfPrim = refractHit.primitive_id;
                            uint rfPrimGlobal = instanceOffsets[refractHit.instance_id] + rfPrim;
                            TriTexInfo rfti = triTexInfos[rfPrimGlobal];
                            if (rfti.atlas_w >= 0.0 && rfti.tex_w >= 1.0) {
                                float2 rfBary = refractHit.triangle_barycentric_coord;
                                float rfBw = 1.0 - rfBary.x - rfBary.y;
                                uint ri0 = indices[rfPrim*3], ri1 = indices[rfPrim*3+1], ri2 = indices[rfPrim*3+2];
                                float2 rfUV = getUV(vertices, ri0)*rfBw + getUV(vertices, ri1)*rfBary.x + getUV(vertices, ri2)*rfBary.y;
                                float rftw = rfti.tex_w, rfth = rfti.tex_h;
                                float rsu = rfUV.x - floor(rfUV.x / rftw) * rftw;
                                float rsv = rfUV.y - floor(rfUV.y / rfth) * rfth;
                                int raw_ = atlasTexture.get_width(), rah_ = atlasTexture.get_height();
                                int rfax = clamp((int)(rfti.atlas_u*(float)raw_+rsu), 0, raw_-1);
                                int rfay = clamp((int)(rfti.atlas_v*(float)rah_+rsv), 0, rah_-1);
                                float3 sampled = atlasTexture.read(uint2(rfax, rfay)).rgb;
                                // Attenuate with depth through water
                                float3 waterAbs = float3(0.08, 0.02, 0.03) * refractHit.distance;
                                refractColor = sampled * max(rfti.pad0, 0.3) * exp(-waterAbs);
                            }
                        }
                    }

                    // Fresnel: more reflection at grazing angles, more
                    // refraction at normal incidence. Schlick approx.
                    float cosI = saturate(-dot(r.direction, liqN));
                    float fresnel = 0.04 + 0.96 * pow(1.0 - cosI, 5.0);
                    float3 waterBase = texBase * tint * (0.6 + warp * 0.4) + caustic;
                    float3 transmitted = mix(waterBase, refractColor, 0.55);
                    baseColor = mix(transmitted, reflColor, fresnel);
                } else if (liquidType < 2.5) {
                    // Lava — emissive, weak reflection. Clamp the emissive
                    // contribution so temporal accumulators (SVGF / MetalFX)
                    // don't blow up into fireflies.
                    float pulse = sin(time * 2.5 + hitPos.x * 0.06 + hitPos.y * 0.04) * 0.25 + 0.75;
                    float3 hotTint = float3(1.2, 0.6, 0.2);
                    float hotSpot = pow(warp, 2.0) * pulse;
                    float3 lavaEmissive = texBase * hotTint * (0.5 + hotSpot * 0.8)
                                        + float3(hotSpot * 0.3, hotSpot * 0.1, 0.0);
                    lavaEmissive = min(lavaEmissive, float3(1.8)); // cap peak
                    baseColor = mix(lavaEmissive, reflColor, 0.15);
                } else if (liquidType < 3.5) {
                    // Slime — use texture with green tint and bubbling, medium reflection
                    float3 slimeTint = float3(0.5, 1.0, 0.4);
                    float bubble = pow(max(sin(hitPos.x * 0.2 + time * 3.0) * cos(hitPos.y * 0.25 + time * 2.2), 0.0), 4.0) * 0.2;
                    baseColor = mix(texBase * slimeTint * (0.5 + warp * 0.5) + float3(0.01, bubble, 0.01), reflColor, 0.3);
                } else {
                    // Teleporter — purple energy overlay, warped reflection
                    float pulse = sin(time * 4.0 + atan2(hitPos.y, hitPos.x) * 3.0) * 0.3 + 0.7;
                    baseColor = mix(texBase * float3(0.6, 0.3, 0.9) * pulse, reflColor, 0.45);
                }
            }
            // === BSP lightmap + directional lighting ===
            float bspLight = tti.pad0; // BSP precomputed average light for this surface
            if (tti.atlas_w < 0.0) {
                bspLight = 0.4; // Base ambient fallback for dynamic entities (monsters, weapons)
            }
            
            float3 keyDirCenter = normalize(float3(0.4, 0.3, 0.85));
            
            // High-frequency jitter for temporal soft shadows
            uint seed = tid.x + tid.y * 8192 + uint(time * 60.0) * 10000;
            seed = (seed ^ 61) ^ (seed >> 16);
            seed = seed + (seed << 3);
            seed = seed ^ (seed >> 4);
            seed = seed * 0x27d4eb2d;
            float rx = fract(float(seed) / 4294967296.0) * 2.0 - 1.0;
            float ry = fract(float(seed * 13) / 4294967296.0) * 2.0 - 1.0;
            float3 jitter = float3(rx, ry, fract(float(seed * 17) / 4294967296.0) * 2.0 - 1.0) * 0.02;
            
            float3 keyDir = normalize(keyDirCenter + jitter);
            float keyDiffuse = max(dot(N, keyDir), 0.0);

            // rtQuality: 0=off, 1=low (lightmap only), 2=medium (1 shadow
            // ray + 1 GI bounce), 3=high (2 shadow rays + 1 GI), 4=ultra
            // (4 shadow rays + 2 GI bounces). Respecting this at the
            // dispatch level is what turns the RT Quality picker in the
            // launcher from a toast into a real performance knob.
            float shadowTerm;
            if (rtQuality <= 1) {
                shadowTerm = 1.0; // no shadow tracing on LOW
            } else {
                // ReSTIR-lite: evaluate 2× as many key-direction candidates
                // as the quality level asks for, importance-sample to pick
                // the single direction with the highest target-function
                // weight (cosine term), and cast ONE shadow ray. This is
                // reservoir sampling without temporal reuse — it turns the
                // original averaged multi-ray estimator into a better-
                // conditioned single-ray estimator. The cost of ray casts
                // drops; the directionality gets sharper because biasing
                // sample selection toward lit surface normals kills the
                // worst-case shadow terminators.
                int candidateCount = (rtQuality >= 4) ? 8 : (rtQuality >= 3 ? 4 : 2);
                float totalWeight    = 0.0;
                float3 chosenDir     = keyDirCenter;
                float  chosenWeight  = 0.0;
                for (int si = 0; si < candidateCount; si++) {
                    float3 sJitter = float3(
                        fract(float(seed * (31 + si * 11)) / 4294967296.0) * 2.0 - 1.0,
                        fract(float(seed * (37 + si * 13)) / 4294967296.0) * 2.0 - 1.0,
                        fract(float(seed * (41 + si * 17)) / 4294967296.0) * 2.0 - 1.0) * 0.02;
                    float3 sDir = normalize(keyDirCenter + sJitter);
                    // Target function: cosine between surface normal and
                    // candidate direction. Zero-cos candidates can't light
                    // the surface regardless of visibility, so the
                    // reservoir should never pick them.
                    float w = max(dot(N, sDir), 0.0);
                    totalWeight += w;
                    float rejectRoll = fract(float(seed * (47 + si * 19)) / 4294967296.0);
                    if (totalWeight > 0.0 && rejectRoll < (w / totalWeight)) {
                        chosenDir    = sDir;
                        chosenWeight = w;
                    }
                }
                // Adaptive self-intersection bias — scales with hit distance.
                float shadowBias = 0.05 + dist * 0.0002;
                ray shadowRay;
                shadowRay.origin       = hitPos + N * shadowBias;
                shadowRay.direction    = chosenDir;
                shadowRay.min_distance = shadowBias;
                shadowRay.max_distance = 2000.0;
                float visibility = (isect.intersect(shadowRay, scene).type == intersection_type::triangle) ? 0.1 : 1.0;
                // Scale back up by averaged reservoir weight — the
                // classic RIS estimator returns target(chosen) × sumW /
                // (candidates × target(chosen)) = sumW / candidates,
                // which normalizes the single-sample to an averaged
                // multi-sample approximation.
                float ris = (chosenWeight > 0.0)
                          ? visibility * (totalWeight / (float(candidateCount) * chosenWeight))
                          : 1.0;
                shadowTerm = clamp(ris, 0.0, 1.0);
            }

            // Blend BSP lightmap with directional fill for depth
            float dirContrib = keyDiffuse * shadowTerm * 0.8;
            float totalLight = max(bspLight * 2.5 + dirContrib, 0.25); // Higher ambient ambient clamp
            float3 warmTint = mix(float3(1.0, 0.95, 0.85), float3(1.0), 0.5);
            float3 lighting = warmTint * totalLight;
            
            // True Emissive Surfaces. Detect via luminance-weighted
            // brightness AND high chroma — catches tinted light fixtures
            // (yellow lanterns, blue teleporter panels, red hazard signs)
            // that pure-channel tests missed. Also keeps the high-luma
            // fallback for white light fixtures.
            float primaryLum = dot(baseColor, float3(0.2126, 0.7152, 0.0722));
            float maxCh = max(max(baseColor.r, baseColor.g), baseColor.b);
            float minCh = min(min(baseColor.r, baseColor.g), baseColor.b);
            float chroma = maxCh - minCh;
            bool isEmissive = (primaryLum > 0.85) ||
                              (maxCh > 0.75 && chroma > 0.45); // bright + strongly tinted
            if (isEmissive) {
                // Clamp so a pure-white light fixture doesn't push
                // temporal accumulators to infinity.
                lighting = min(baseColor * 2.0, float3(2.2));
            }
            
            // PBR Specularity based on texture luminance
            float baseLum = dot(baseColor, float3(0.333));
            float specExp = mix(8.0, 64.0, baseLum); // Brighter = sharper highlight
            float3 viewDir = normalize(camOrigin.xyz - hitPos);
            float3 halfVector = normalize(keyDir + viewDir);
            float specTerm = pow(max(dot(N, halfVector), 0.0), specExp) * shadowTerm * baseLum * 0.4;
            lighting += float3(specTerm);

            // === Stochastic Path Tracing GI ===
            // Gated by rtQuality — LOW skips GI entirely, ULTRA does two
            // bounces. Each bounce is expensive, so skipping on LOW is a
            // significant perf win on M1 hardware.
            int giBounces = (rtQuality >= 4) ? 2 : (rtQuality >= 2 ? 1 : 0);
            for (int giPass = 0; giPass < giBounces; giPass++)
            {
                // Cosine-weighted hemisphere sampling for Diffuse GI
                float r1 = fract(float(seed * 23) / 4294967296.0);
                float r2 = fract(float(seed * 29) / 4294967296.0);
                float phi = r1 * 6.2831853;
                float cosTheta = sqrt(r2);
                float sinTheta = sqrt(1.0 - r2);
                float3 H = float3(sinTheta * cos(phi), sinTheta * sin(phi), cosTheta);
                
                float3 tangent = normalize(cross(N, float3(0, 1, 0)));
                if (length(tangent) < 0.1) tangent = normalize(cross(N, float3(1, 0, 0)));
                float3 bitangent = cross(N, tangent);
                float3 bounceDir = normalize(tangent * H.x + bitangent * H.y + N * H.z);
                
                ray bounceRay;
                bounceRay.origin = hitPos + N * 0.1;
                bounceRay.direction = bounceDir;
                bounceRay.min_distance = 0.5;
                bounceRay.max_distance = 800.0;
                auto bounceResult = isect.intersect(bounceRay, scene);
                if (bounceResult.type == intersection_type::triangle) {
                    uint bPrim = bounceResult.primitive_id;
                    float3 bN = getFaceNormal(vertices, indices, bPrim);
                    float bLight = max(dot(bN, keyDir), 0.0) * 0.5 + 0.2;
                    // Sample bounce surface color
                    uint bPrimGlobal = instanceOffsets[bounceResult.instance_id] + bPrim;
                    TriTexInfo btti = triTexInfos[bPrimGlobal];
                    float3 bColor;
                    if (btti.atlas_w < 0.0 || btti.tex_w < 1.0) {
                        bColor = float3(0.5, 0.4, 0.3);
                    } else {
                        float2 bBary = bounceResult.triangle_barycentric_coord;
                        float bBw = 1.0 - bBary.x - bBary.y;
                        uint bi0 = indices[bPrim*3], bi1 = indices[bPrim*3+1], bi2 = indices[bPrim*3+2];
                        float2 bUV = getUV(vertices, bi0)*bBw + getUV(vertices, bi1)*bBary.x + getUV(vertices, bi2)*bBary.y;
                        float btw = btti.tex_w, bth = btti.tex_h;
                        float bsu = bUV.x - floor(bUV.x / btw) * btw;
                        float bsv = bUV.y - floor(bUV.y / bth) * bth;
                        bsu = clamp(bsu, 0.0f, btw - 1.0f);
                        bsv = clamp(bsv, 0.0f, bth - 1.0f);
                        int baw = atlasTexture.get_width(), bah = atlasTexture.get_height();
                        int bax = clamp((int)(btti.atlas_u*(float)baw+bsu), 0, baw-1);
                        int bay = clamp((int)(btti.atlas_v*(float)bah+bsv), 0, bah-1);
                        bColor = atlasTexture.read(uint2(bax, bay)).rgb;
                    }
                    float bBspLight = max(btti.pad0, 0.2f);
                    lighting += bColor * bBspLight * 0.15; // Normal diffuse bounce
                } else {
                    // Bounce hits sky — add subtle sky bounce
                    lighting += float3(0.04, 0.05, 0.07);
                }
            }

            // === Dynamic point lights ===
            for (int li = 0; li < numLights; li++) {
                float3 lightPos = float3(dynLights[li].x, dynLights[li].y, dynLights[li].z);
                float lightRad = dynLights[li].radius;
                float3 toLight = lightPos - hitPos;
                float lightDist = length(toLight);
                if (lightDist > lightRad) continue;
                float3 lightDir = toLight / lightDist;
                float atten = 1.0 - (lightDist / lightRad);
                atten *= atten;
                float nDotL = max(dot(N, lightDir), 0.0);
                
                ray dlShadow;
                dlShadow.origin = hitPos + N * 0.5;
                dlShadow.direction = lightDir;
                dlShadow.min_distance = 0.1;
                dlShadow.max_distance = lightDist - 1.0;
                float dlShadowTerm = (isect.intersect(dlShadow, scene).type == intersection_type::triangle) ? 0.0 : 1.0;
                
                lighting += float3(1.0, 0.8, 0.5) * nDotL * atten * dlShadowTerm * 2.5;
            }

            // === ReSTIR DI over emissive world surfaces ===
            //
            // Weighted-reservoir sampling: pick `kRestir` random emissive
            // triangles, weight each candidate by its inverse-square
            // distance × cosine-to-surface, pick one via RIS. Cast a
            // single shadow ray. The estimator normalizes back to an
            // unbiased many-light contribution: pHat(chosen) × sumW /
            // (kRestir × pHat(chosen)) = sumW / kRestir.
            if (useReSTIR != 0 && emissiveCount > 0) {
                const int kRestir = 4;
                int chosenIdx = -1;
                float3 chosenCentroid = float3(0);
                float3 chosenColor = float3(1);
                float chosenPHat = 0.0;
                float totalW = 0.0;
                for (int ri = 0; ri < kRestir; ri++) {
                    uint  rndIdx = uint(fract(float(seed * (53 + ri * 23)) / 4294967296.0) * float(emissiveCount));
                    uint  eTri   = emissiveTris[rndIdx];
                    // Centroid of emissive triangle.
                    uint ei0 = indices[eTri*3], ei1 = indices[eTri*3+1], ei2 = indices[eTri*3+2];
                    float3 p0 = getPos(vertices, ei0);
                    float3 p1 = getPos(vertices, ei1);
                    float3 p2 = getPos(vertices, ei2);
                    float3 centroid = (p0 + p1 + p2) * (1.0/3.0);
                    float3 toLight = centroid - hitPos;
                    float  dsq = dot(toLight, toLight);
                    if (dsq < 0.1 || dsq > 2000.0 * 2000.0) continue;
                    float3 lDir = toLight * rsqrt(dsq);
                    float  nDotL = max(dot(N, lDir), 0.0);
                    if (nDotL < 0.001) continue;
                    // Target function: cosine × 1/dist².
                    float pHat = nDotL / dsq;
                    totalW += pHat;
                    float rr = fract(float(seed * (71 + ri * 37)) / 4294967296.0);
                    if (totalW > 0.0 && rr < pHat / totalW) {
                        chosenIdx = int(rndIdx);
                        chosenCentroid = centroid;
                        chosenPHat = pHat;
                        // Sample the emissive triangle's atlas color for tint.
                        // (We read via the world-BLAS offset = 0 so this
                        // is always in the world region of triTexInfos.)
                        TriTexInfo eTti = triTexInfos[eTri];
                        if (eTti.atlas_w >= 0.0 && eTti.tex_w >= 1.0) {
                            float esu = eTti.tex_w * 0.5;
                            float esv = eTti.tex_h * 0.5;
                            int eraw = atlasTexture.get_width(), erah = atlasTexture.get_height();
                            int eax = clamp((int)(eTti.atlas_u*(float)eraw+esu), 0, eraw-1);
                            int eay = clamp((int)(eTti.atlas_v*(float)erah+esv), 0, erah-1);
                            chosenColor = atlasTexture.read(uint2(eax, eay)).rgb;
                        }
                    }
                }
                if (chosenIdx >= 0 && chosenPHat > 0.0) {
                    float3 toLight = chosenCentroid - hitPos;
                    float  dist2 = length(toLight);
                    float3 lDir  = toLight / max(dist2, 0.01);
                    float  shadowBias = 0.05 + dist * 0.0002;
                    ray srr;
                    srr.origin = hitPos + N * shadowBias;
                    srr.direction = lDir;
                    srr.min_distance = shadowBias;
                    srr.max_distance = dist2 - 0.5;
                    bool visible = (isect.intersect(srr, scene).type != intersection_type::triangle);
                    if (visible) {
                        float nDotL = max(dot(N, lDir), 0.0);
                        // RIS-normalized contribution. 1/dist² already
                        // baked into pHat; we factor back out the chosen
                        // pHat and apply the reservoir's sum.
                        float contribScale = (totalW / (float(kRestir) * chosenPHat));
                        float atten = nDotL / (dist2 * dist2 * 0.00001 + 1.0);
                        lighting += chosenColor * atten * contribScale * 0.15;
                    }
                }
            }

            float3 color = baseColor * lighting;

            // Distance fog. Two curves: open-air (warm dusty) and water
            // (greenish soup) when the listener is submerged. The water
            // fog density ramps much faster — real Quake underwater has
            // ~200 unit visibility compared to ~5000 in air — so divers
            // lose sight of far geometry as expected.
            if (underwaterFlag != 0) {
                // Multi-octave volumetric-ish: base absorption + density
                // noise to avoid the solid-color look a flat mix gives.
                float waterFog = saturate(dist / 600.0);
                float3 waterColor = float3(0.10, 0.28, 0.30);
                // Subtle caustic noise modulating fog color
                float n = hash(hitPos.xy * 0.01 + float2(time * 0.2, 0.0)) * 0.15;
                color = mix(color, waterColor + float3(n * 0.05), waterFog * waterFog);
            } else {
                float fog = saturate(dist / 5000.0);
                color = mix(color, float3(0.20, 0.17, 0.14), fog * fog);
            }

            // Filmic tone mapping (gentler curve for dark areas)
            color = color / (color + 0.8);
            color = pow(color, float3(0.88));

            outTexture.write(float4(color, 1.0), tid);

            // === Write depth for MetalFX temporal ===
            float normalizedDepth = saturate(dist / 100000.0);
            depthTexture.write(float4(normalizedDepth, 0, 0, 0), tid);

            // === Motion vectors: reproject hit point through previous camera ===
            {
                // Project hitPos into previous frame screen space
                float3 toPrev = hitPos - prevCamOrigin.xyz;
                float prevZ = dot(toPrev, prevCamForward.xyz);
                float2 prevScreen = float2(0.0);
                if (prevZ > 0.01) {
                    float prevX = dot(toPrev, prevCamRight.xyz) / prevZ;
                    float prevY = dot(toPrev, prevCamUp.xyz) / prevZ;
                    prevScreen = float2(prevX, -prevY); // Flip Y to match UV convention
                }
                // Current screen position
                float2 curScreen = uv;
                // Motion = current - previous (in NDC space, scaled to pixels)
                float2 motion = (curScreen - prevScreen) * 0.5; // Half-res NDC
                motionTexture.write(float4(motion, 0, 0), tid);
            }
        }
    )";
    auto* pRTLib = _pDevice->newLibrary(NS::String::string(rtShaderSource, UTF8StringEncoding), nullptr, &pError);
    if (pRTLib) {
        auto* pRTFn = pRTLib->newFunction(NS::String::string("raytraceMain", UTF8StringEncoding));
        _pRTComputeState = _pDevice->newComputePipelineState(pRTFn, &pError);
        // Retain the function for argument-encoder derivation below.
        // Released in VID_Shutdown.
        _pRTFunction = pRTFn;
        _pRTArgEncoder = pRTFn->newArgumentEncoder(5);
        if (_pRTArgEncoder) {
            _pRTArgBuffer = _pDevice->newBuffer(
                _pRTArgEncoder->encodedLength(),
                MTL::ResourceStorageModeShared);
            _pRTArgBuffer->setLabel(NS::String::string("RT arg buffer", NS::UTF8StringEncoding));
            Con_Printf("RT: argument buffer ready (%lu bytes)\n",
                       (unsigned long)_pRTArgEncoder->encodedLength());
        }
        pRTLib->release();
    }
    pLib->release(); pDesc->release();
}

static void UpdatePaletteLUT(unsigned char *palette) {
    if (!_pPaletteTexture) return;
    uint32_t lut[256];
    for (int i = 0; i < 256; i++) {
        unsigned char r = palette[i * 3 + 0], g = palette[i * 3 + 1], b = palette[i * 3 + 2];
        lut[i] = (255u << 24) | ((uint32_t)b << 16) | ((uint32_t)g << 8) | r;
    }
    _pPaletteTexture->replaceRegion(MTL::Region(0, 0, 256, 1), 0, lut, 256 * 4);
}

static int vid_mode = 0;
static const char* vid_modes[] = { "640x480", "800x600", "1024x768", "1280x720", "1920x1080" };
static int vid_mode_ws[] = { 640, 800, 1024, 1280, 1920 };
static int vid_mode_hs[] = { 480, 600, 768, 720, 1080 };
cvar_t vid_rtx = {"vid_rtx", "1"};

extern "C" void Draw_String(int x, int y, char *str);
extern "C" void Sys_SetWindowSize(int width, int height);

static int _vidMenuCursor = 0;
static const char* _mfxModeNames[] = { "OFF", "Spatial", "Temporal" };

static void VID_MenuDraw(void) {
    extern cvar_t sensitivity;
    extern cvar_t sv_aim;
    MetalQuakeSettings* s = MQ_GetSettings();
    Draw_String(72, 32, (char*)"Video Options (Metal)");
    // 12 px row spacing matches Draw_String's 8 px baseline with a 4 px
    // gutter between rows. A full 20 px gap before Apply makes the
    // actionable row read as visually separate from the toggles above.
    const int itemY[] = { 52, 64, 76, 88, 100, 112, 124, 136, 148, 160, 172, 184, 196, 216 };
    // Labels render at x=72 in 8x8 Quake font; the ON/OFF value column
    // starts at x=180. That caps usable label width at ~13 characters
    // before the two collide. Anything longer gets shortened here.
    const char* itemLabels[] = { "Resolution:", "Raytracing:", "MetalFX:", "Denoise:",
                                  "SSAO:", "EDR/HDR:", "Sensitivity:", "Auto-aim:",
                                  "CRT Mode:", "Glass HUD:", "Water FX:",
                                  "Deadzone:", "Chroma AB:", "Apply" };
    for (int i = 0; i < 14; i++) {
        if (i == _vidMenuCursor) Draw_Character(56, itemY[i], 12 + ((int)(realtime * 4) & 1));
        Draw_String(72, itemY[i], (char*)itemLabels[i]);
    }
    Draw_String(180, itemY[0], (char*)vid_modes[vid_mode]);
    Draw_String(180, itemY[1], (char*)(vid_rtx.value ? "ON" : "OFF"));
    Draw_String(180, itemY[2], (char*)_mfxModeNames[s->metalfx_mode]);
    Draw_String(180, itemY[3], (char*)(s->neural_denoise ? "ON" : "OFF"));
    Draw_String(180, itemY[4], (char*)(s->ssao_enabled ? "ON" : "OFF"));
    Draw_String(180, itemY[5], (char*)(s->edr_enabled ? "ON" : "OFF"));
    char sensStr[16]; snprintf(sensStr, sizeof(sensStr), "%.1f", sensitivity.value);
    Draw_String(180, itemY[6], sensStr);
    Draw_String(180, itemY[7], (char*)(sv_aim.value < 1.0 ? "ON" : "OFF"));
    Draw_String(180, itemY[8], (char*)(s->crt_mode ? "ON" : "OFF"));
    Draw_String(180, itemY[9], (char*)(s->liquid_glass_ui ? "ON" : "OFF"));
    Draw_String(180, itemY[10], (char*)(s->underwater_fx ? "ON" : "OFF"));
    char dzStr[16]; snprintf(dzStr, sizeof(dzStr), "%.2f", s->controller_deadzone);
    Draw_String(180, itemY[11], dzStr);
    Draw_String(180, itemY[12], (char*)(s->chromatic_aberration ? "ON" : "OFF"));
}

static void VID_MenuKey(int key) {
    extern cvar_t sensitivity;
    extern cvar_t sv_aim;
    MetalQuakeSettings* s = MQ_GetSettings();
    if (key == K_ESCAPE) { 
        extern keydest_t key_dest; extern int m_state;
        key_dest = key_game; m_state = 0;
        return; 
    }
    if (key == K_UPARROW) { _vidMenuCursor--; if (_vidMenuCursor < 0) _vidMenuCursor = 13; }
    else if (key == K_DOWNARROW) { _vidMenuCursor++; if (_vidMenuCursor > 13) _vidMenuCursor = 0; }
    if (_vidMenuCursor == 0) {
        if (key == K_LEFTARROW) { vid_mode--; if (vid_mode < 0) vid_mode = 4; }
        else if (key == K_RIGHTARROW) { vid_mode++; if (vid_mode > 4) vid_mode = 0; }
    } else if (_vidMenuCursor == 1) {
        if (key == K_LEFTARROW || key == K_RIGHTARROW || key == K_ENTER) Cvar_SetValue("vid_rtx", vid_rtx.value ? 0 : 1);
    } else if (_vidMenuCursor == 2) {
        if (key == K_RIGHTARROW || key == K_ENTER) { s->metalfx_mode = (MQMetalFXMode)(((int)s->metalfx_mode + 1) % 3); }
        else if (key == K_LEFTARROW) { s->metalfx_mode = (MQMetalFXMode)(((int)s->metalfx_mode + 2) % 3); }
    } else if (_vidMenuCursor == 3) {
        if (key == K_LEFTARROW || key == K_RIGHTARROW || key == K_ENTER) s->neural_denoise = !s->neural_denoise;
    } else if (_vidMenuCursor == 4) {
        if (key == K_LEFTARROW || key == K_RIGHTARROW || key == K_ENTER) s->ssao_enabled = !s->ssao_enabled;
    } else if (_vidMenuCursor == 5) {
        if (key == K_LEFTARROW || key == K_RIGHTARROW || key == K_ENTER) s->edr_enabled = !s->edr_enabled;
    } else if (_vidMenuCursor == 6) {
        if (key == K_LEFTARROW) { float sv = sensitivity.value - 0.5; if (sv < 1.0) sv = 1.0; Cvar_SetValue("sensitivity", sv); }
        else if (key == K_RIGHTARROW) { float sv = sensitivity.value + 0.5; if (sv > 20.0) sv = 20.0; Cvar_SetValue("sensitivity", sv); }
    } else if (_vidMenuCursor == 7) {
        if (key == K_LEFTARROW || key == K_RIGHTARROW || key == K_ENTER) {
            Cvar_SetValue("sv_aim", sv_aim.value < 1.0 ? 1.0 : 0.93);
        }
    } else if (_vidMenuCursor == 8) {
        if (key == K_LEFTARROW || key == K_RIGHTARROW || key == K_ENTER) s->crt_mode = !s->crt_mode;
    } else if (_vidMenuCursor == 9) {
        if (key == K_LEFTARROW || key == K_RIGHTARROW || key == K_ENTER) s->liquid_glass_ui = !s->liquid_glass_ui;
    } else if (_vidMenuCursor == 10) {
        if (key == K_LEFTARROW || key == K_RIGHTARROW || key == K_ENTER) s->underwater_fx = !s->underwater_fx;
    } else if (_vidMenuCursor == 11) {
        if (key == K_LEFTARROW) {
            s->controller_deadzone -= 0.05f;
            if (s->controller_deadzone < 0.0f) s->controller_deadzone = 0.0f;
        } else if (key == K_RIGHTARROW) {
            s->controller_deadzone += 0.05f;
            if (s->controller_deadzone > 0.5f) s->controller_deadzone = 0.5f;
        }
    } else if (_vidMenuCursor == 12) {
        if (key == K_LEFTARROW || key == K_RIGHTARROW || key == K_ENTER) s->chromatic_aberration = !s->chromatic_aberration;
    } else if (_vidMenuCursor == 13) {
        if (key == K_ENTER) {
            Sys_SetWindowSize(vid_mode_ws[vid_mode], vid_mode_hs[vid_mode]);
            // Apply also persists to disk so menu changes survive a crash.
            extern void MQ_SaveSettings(const char* path);
            MQ_SaveSettings("id1/metal_quake.cfg");
        }
    }
}

extern "C" void* Sys_CreateWindow(int width, int height, void* pDevice);
extern "C" void* Sys_GetNextDrawable(void* layer);

extern "C" void VID_Init(unsigned char *palette) {
    static bool already_initialized = false; if (already_initialized) return; already_initialized = true;
    // Window/display size — 1280x960 (4x internal 320x240)
    // Rendered directly into drawable; GPU texture sampling handles upscale
    int w = 1280, h = 960;
    int i; if ((i = COM_CheckParm("-width")) && i + 1 < com_argc) w = atoi(com_argv[i+1]);
    if ((i = COM_CheckParm("-height")) && i + 1 < com_argc) h = atoi(com_argv[i+1]);
    // Internal software renderer always at 320x240 — MetalFX does the upscale
    vid.width  = 320; vid.height = 240; vid.rowbytes = vid.width;
    vid.buffer = (byte*)malloc(vid.width * vid.height);
    vid.aspect = ((float)vid.height / (float)vid.width) * (320.0f / 240.0f);
    vid.conwidth = vid.width; vid.conheight = vid.height; vid.conrowbytes = vid.rowbytes; vid.conbuffer = (byte*)vid.buffer;
    vid.colormap = host_colormap; vid.fullbright = 256 - LittleLong (*((int *)vid.colormap + 2048));
    vid.numpages = 1;
    _pZBufferMem = (short*)malloc(vid.width * vid.height * sizeof(short)); d_pzbuffer = _pZBufferMem; d_zwidth = vid.width; d_zrowbytes = vid.width * 2;
    _pSurfCacheMem = (byte*)malloc(4 * 1024 * 1024); D_InitCaches(_pSurfCacheMem, 4 * 1024 * 1024);
    _pDevice = MTL::CreateSystemDefaultDevice(); _pCommandQueue = _pDevice->newCommandQueue();

    // Create a residency set for long-lived resources (atlas, world
    // buffers, BLAS) and attach it to the command queue so the driver
    // doesn't re-evaluate residency of those objects each frame.
    if (MQ_Residency_IsAvailable()) {
        _pResidencySet = MQ_Residency_Create(_pDevice, "com.metalquake.rt");
        if (_pResidencySet) {
            MQ_Residency_AttachToQueue(_pCommandQueue, _pResidencySet);
            Con_Printf("Residency: set attached to command queue (macOS 15+)\n");
        }
    }
    BuildPipeline(); _frameSemaphore = dispatch_semaphore_create(MaxFramesInFlight);
    _pMetalLayer = (CA::MetalLayer*)Sys_CreateWindow(w, h, _pDevice);
    auto* pTexDesc = MTL::TextureDescriptor::texture2DDescriptor(MTL::PixelFormatR8Uint, vid.width, vid.height, false);
    pTexDesc->setUsage(MTL::TextureUsageShaderRead); pTexDesc->setStorageMode(MTL::StorageModeShared);
    for (int j = 0; j < MaxFramesInFlight; ++j) _pIndexTextures[j] = _pDevice->newTexture(pTexDesc);
    // RT output at 2x internal resolution for sharper raytracing
    // RT internal resolution honors metalfx_scale. Default 2.0 keeps the
    // 640×480 internal → display upscale. The user slider ranges 1.0–4.0;
    // values outside that clamp to defaults. Resizing later requires a
    // restart since MetalFX scalers bake their input size at creation.
    float mfxScale = MQ_GetSettings()->metalfx_scale;
    if (!(mfxScale >= 1.0f && mfxScale <= 4.0f)) mfxScale = 2.0f;
    int rtW = (int)((float)vid.width  * mfxScale + 0.5f);
    int rtH = (int)((float)vid.height * mfxScale + 0.5f);
    Con_Printf("MetalFX: internal RT resolution %dx%d (scale %.2f)\n", rtW, rtH, mfxScale);
    auto* pRTDesc = MTL::TextureDescriptor::texture2DDescriptor(MTL::PixelFormatBGRA8Unorm, rtW, rtH, false);
    pRTDesc->setUsage(MTL::TextureUsageShaderWrite | MTL::TextureUsageShaderRead); pRTDesc->setStorageMode(MTL::StorageModePrivate);
    _pRTOutputTexture = _pDevice->newTexture(pRTDesc);
    // Depth texture for MetalFX temporal (R32Float, same size as RT output)
    auto* pDepthDesc = MTL::TextureDescriptor::texture2DDescriptor(MTL::PixelFormatR32Float, rtW, rtH, false);
    pDepthDesc->setUsage(MTL::TextureUsageShaderWrite | MTL::TextureUsageShaderRead); pDepthDesc->setStorageMode(MTL::StorageModePrivate);
    _pRTDepthTexture = _pDevice->newTexture(pDepthDesc);
    // Motion vector texture for MetalFX temporal (RG16Float, same size as RT output)
    auto* pMotionDesc = MTL::TextureDescriptor::texture2DDescriptor(MTL::PixelFormatRG16Float, rtW, rtH, false);
    pMotionDesc->setUsage(MTL::TextureUsageShaderWrite | MTL::TextureUsageShaderRead); pMotionDesc->setStorageMode(MTL::StorageModePrivate);
    _pRTMotionTexture = _pDevice->newTexture(pMotionDesc);
    auto* pPalDesc = MTL::TextureDescriptor::texture2DDescriptor(MTL::PixelFormatRGBA8Unorm, 256, 1, false);
    _pPaletteTexture = _pDevice->newTexture(pPalDesc); UpdatePaletteLUT(palette);
    auto* pInterDesc = MTL::TextureDescriptor::texture2DDescriptor(MTL::PixelFormatBGRA8Unorm, vid.width, vid.height, false);
    pInterDesc->setUsage(MTL::TextureUsageRenderTarget | MTL::TextureUsageShaderRead);
    _pIntermediateTexture = _pDevice->newTexture(pInterDesc);
    // MetalFX Spatial Scaler — upscales software renderer output (320x240 → window res)
    auto* pScalerDesc = MetalFX::SpatialScalerDescriptor::alloc()->init();
    pScalerDesc->setInputWidth(vid.width); pScalerDesc->setInputHeight(vid.height);
    pScalerDesc->setOutputWidth(w); pScalerDesc->setOutputHeight(h);
    pScalerDesc->setColorFormat(MTL::PixelFormatBGRA8Unorm); pScalerDesc->setOutputFormat(MTL::PixelFormatBGRA8Unorm);
    pScalerDesc->setColorProcessingMode(0);
    _pSpatialScaler = pScalerDesc->newSpatialScaler(_pDevice);
    if (_pSpatialScaler) Con_Printf("MetalFX: Spatial scaler created (%dx%d → %dx%d)\n", vid.width, vid.height, w, h);
    else Con_Printf("MetalFX: Spatial scaler FAILED — falling back to blit\n");
    // MetalFX Temporal Scaler — upgrades RT output using depth + motion vectors
    auto* pTempDesc = MetalFX::TemporalScalerDescriptor::alloc()->init();
    pTempDesc->setInputWidth(rtW); pTempDesc->setInputHeight(rtH);
    pTempDesc->setOutputWidth(w); pTempDesc->setOutputHeight(h);
    pTempDesc->setColorFormat(MTL::PixelFormatBGRA8Unorm);
    pTempDesc->setDepthFormat(MTL::PixelFormatR32Float);
    pTempDesc->setMotionFormat(MTL::PixelFormatRG16Float);
    pTempDesc->setOutputFormat(MTL::PixelFormatBGRA8Unorm);
    _pTemporalScaler = pTempDesc->newTemporalScaler(_pDevice);
    if (_pTemporalScaler) Con_Printf("MetalFX: Temporal scaler created (%dx%d → %dx%d)\n", rtW, rtH, w, h);
    else Con_Printf("MetalFX: Temporal scaler FAILED\n");
    // MetalFX upscaled output texture (window resolution)
    auto* pMFXOutDesc = MTL::TextureDescriptor::texture2DDescriptor(MTL::PixelFormatBGRA8Unorm, w, h, false);
    pMFXOutDesc->setUsage(MTL::TextureUsageShaderWrite | MTL::TextureUsageShaderRead);
    pMFXOutDesc->setStorageMode(MTL::StorageModePrivate);
    _pMFXOutputTexture = _pDevice->newTexture(pMFXOutDesc);
    if (_pMFXOutputTexture) Con_Printf("MetalFX: Output texture created (%dx%d)\n", w, h);
    // --- GPU Bilateral Denoiser (inline Metal compute shader) ---
    // À-trous wavelet filter: edge-aware spatial denoising for noisy RT output
    {
        const char* denoiseShader = R"(
#include <metal_stdlib>
using namespace metal;

// Edge-aware bilateral filter — preserves edges while smoothing noise
// Uses cross-bilateral weights from depth + normal similarity
kernel void bilateralDenoise(
    texture2d<float, access::read>  input   [[texture(0)]],
    texture2d<float, access::write> output  [[texture(1)]],
    texture2d<float, access::read>  depthTx [[texture(2)]],
    constant int&                   stepWidth [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= input.get_width() || gid.y >= input.get_height()) return;
    
    // 5-tap À-trous kernel offsets and weights
    const int2 offsets[5] = { int2(0,0), int2(1,0), int2(-1,0), int2(0,1), int2(0,-1) };
    const float weights[5] = { 0.375, 0.15625, 0.15625, 0.15625, 0.15625 };
    
    float4 centerColor = input.read(gid);
    float  centerDepth = depthTx.read(gid).r;
    
    float4 sumColor = float4(0.0);
    float  sumWeight = 0.0;
    
    // Tighter edge preservation. sigmaColor=0.1 was lenient enough that
    // adjacent pixel-art texels blurred into each other, giving the scene
    // a plasticky / waxy feel. 0.035 keeps every texel-level detail as an
    // "edge" the à-trous filter won't cross.
    float sigmaColor = 0.035;
    float sigmaDepth = 0.02;
    
    for (int i = 0; i < 5; i++) {
        int2 samplePos = int2(gid) + offsets[i] * stepWidth;
        // Clamp to texture bounds
        samplePos = clamp(samplePos, int2(0), int2(input.get_width()-1, input.get_height()-1));
        
        float4 sampleColor = input.read(uint2(samplePos));
        float  sampleDepth = depthTx.read(uint2(samplePos)).r;
        
        // Edge-stop: color difference
        float3 cdiff = centerColor.rgb - sampleColor.rgb;
        float colorDist = dot(cdiff, cdiff);
        float wColor = exp(-colorDist / (2.0 * sigmaColor * sigmaColor));
        
        // Edge-stop: depth difference
        float depthDiff = abs(centerDepth - sampleDepth);
        float wDepth = exp(-depthDiff / (2.0 * sigmaDepth * sigmaDepth));
        
        float w = weights[i] * wColor * wDepth;
        sumColor += sampleColor * w;
        sumWeight += w;
    }
    
    // NaN guard: if every weighted sample was zero (disocclusion + depth
    // discontinuity simultaneously), fall back to the center color so the
    // output stays finite. Infinity/NaN here propagates into the next
    // à-trous pass and the temporal accumulator.
    float4 result = (sumWeight > 0.0001) ? (sumColor / sumWeight) : centerColor;
    if (any(isnan(result)) || any(isinf(result))) result = centerColor;
    output.write(result, gid);
}
        )";
        NS::Error* error = nullptr;
        auto* src = NS::String::string(denoiseShader, NS::UTF8StringEncoding);
        auto* lib = _pDevice->newLibrary(src, nullptr, &error);
        if (lib) {
            auto* fn = lib->newFunction(NS::String::string("bilateralDenoise", NS::UTF8StringEncoding));
            if (fn) {
                _pDenoiseState = _pDevice->newComputePipelineState(fn, &error);
                if (_pDenoiseState) Con_Printf("Denoiser: GPU bilateral filter compiled\n");
                fn->release();
            }
            lib->release();
            // Scratch texture for ping-pong (same format/size as RT output)
            auto* pScratchDesc = MTL::TextureDescriptor::texture2DDescriptor(MTL::PixelFormatBGRA8Unorm, rtW, rtH, false);
            pScratchDesc->setUsage(MTL::TextureUsageShaderWrite | MTL::TextureUsageShaderRead);
            pScratchDesc->setStorageMode(MTL::StorageModePrivate);
            _pDenoiseScratch = _pDevice->newTexture(pScratchDesc);

            // SVGF textures.
            //   history   — previous frame's denoised color (BGRA8 to match RT output)
            //   moments   — per-pixel (luma, luma²) history for variance estimation
            //   variance  — scalar variance used to modulate bilateral weights
            auto* pHistDesc = MTL::TextureDescriptor::texture2DDescriptor(MTL::PixelFormatBGRA8Unorm, rtW, rtH, false);
            pHistDesc->setUsage(MTL::TextureUsageShaderWrite | MTL::TextureUsageShaderRead);
            pHistDesc->setStorageMode(MTL::StorageModePrivate);
            _pSVGFHistoryTexture = _pDevice->newTexture(pHistDesc);

            auto* pMomDesc = MTL::TextureDescriptor::texture2DDescriptor(MTL::PixelFormatRG16Float, rtW, rtH, false);
            pMomDesc->setUsage(MTL::TextureUsageShaderWrite | MTL::TextureUsageShaderRead);
            pMomDesc->setStorageMode(MTL::StorageModePrivate);
            _pSVGFMomentsTexture = _pDevice->newTexture(pMomDesc);

            auto* pVarDesc = MTL::TextureDescriptor::texture2DDescriptor(MTL::PixelFormatR16Float, rtW, rtH, false);
            pVarDesc->setUsage(MTL::TextureUsageShaderWrite | MTL::TextureUsageShaderRead);
            pVarDesc->setStorageMode(MTL::StorageModePrivate);
            _pSVGFVarianceTexture = _pDevice->newTexture(pVarDesc);

            // Compile the reprojection compute kernel.
            const char* svgfShader = R"(
#include <metal_stdlib>
using namespace metal;

// SVGF — Spatiotemporal Variance-Guided Filtering.
//
// Kernel 1 (svgfReproject): warp the previous frame's color + moments
// through current-frame motion vectors, blend with current, and write
// an updated moments buffer tracking luma mean + mean-squared.
//
// Kernel 2 (svgfVariance): 3x3 spatial window estimate of variance from
// the moments buffer, output a single-channel texture the à-trous
// bilateral reads to modulate its color-stop threshold.
kernel void svgfReproject(
    texture2d<float, access::read>       current  [[texture(0)]],
    texture2d<float, access::read>       history  [[texture(1)]],
    texture2d<float, access::read>       motion   [[texture(2)]],
    texture2d<float, access::write>      output   [[texture(3)]],
    texture2d<float, access::read>       momentsIn  [[texture(4)]],
    texture2d<float, access::write>      momentsOut [[texture(5)]],
    constant float&                      alpha    [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= current.get_width() || gid.y >= current.get_height()) return;

    float2 mv = motion.read(gid).xy;
    float2 prevUV = float2(gid) - mv * float2(current.get_width(), current.get_height());
    int2 prevPx = int2(round(prevUV));

    float4 cur = current.read(gid);
    float4 prev = cur;
    float2 prevMoments = float2(0.0);
    bool reproj = (prevPx.x >= 0 && prevPx.y >= 0 &&
                   prevPx.x < int(history.get_width()) &&
                   prevPx.y < int(history.get_height()));
    if (reproj) {
        prev = history.read(uint2(prevPx));
        prevMoments = momentsIn.read(uint2(prevPx)).xy;
    }

    float speed = length(mv);
    float a = clamp(alpha * (1.0 - min(speed * 4.0, 0.9)), 0.0, 0.95);
    float4 blended = mix(cur, prev, a);
    output.write(blended, gid);

    // Update moments. curLuma is the Rec. 709 luminance of the current
    // sample; we exponentially blend both luma and luma² so a temporally
    // stable region collects a low variance and a freshly disoccluded
    // region sees high variance (forcing the spatial filter wider).
    float curLuma = dot(cur.rgb, float3(0.2126, 0.7152, 0.0722));
    float newMean   = mix(curLuma,          prevMoments.x, a);
    float newMeanSq = mix(curLuma*curLuma,  prevMoments.y, a);
    momentsOut.write(float4(newMean, newMeanSq, 0.0, 0.0), gid);
}

// Variance = E[X²] - E[X]²; computed per-pixel from the moments buffer.
// We smooth it with a 3x3 box to damp shot noise in the variance estimate
// itself (SVGF paper does this).
kernel void svgfVariance(
    texture2d<float, access::read>       momentsIn  [[texture(0)]],
    texture2d<float, access::write>      varianceOut [[texture(1)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= momentsIn.get_width() || gid.y >= momentsIn.get_height()) return;

    float meanSum = 0.0, meanSqSum = 0.0;
    float weight = 0.0;
    int2 clampMax = int2(momentsIn.get_width() - 1, momentsIn.get_height() - 1);
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            int2 p = clamp(int2(gid) + int2(dx, dy), int2(0), clampMax);
            float2 m = momentsIn.read(uint2(p)).xy;
            meanSum   += m.x;
            meanSqSum += m.y;
            weight    += 1.0;
        }
    }
    float mean   = meanSum   / weight;
    float meanSq = meanSqSum / weight;
    float var    = max(meanSq - mean * mean, 0.0);
    varianceOut.write(float4(var, 0.0, 0.0, 0.0), gid);
}
)";
            NS::Error* svErr = nullptr;
            auto* svSrc = NS::String::string(svgfShader, NS::UTF8StringEncoding);
            auto* svLib = _pDevice->newLibrary(svSrc, nullptr, &svErr);
            if (svLib) {
                auto* svFn = svLib->newFunction(NS::String::string("svgfReproject", NS::UTF8StringEncoding));
                if (svFn) {
                    _pSVGFReprojectState = _pDevice->newComputePipelineState(svFn, &svErr);
                    svFn->release();
                }
                auto* varFn = svLib->newFunction(NS::String::string("svgfVariance", NS::UTF8StringEncoding));
                if (varFn) {
                    _pSVGFVarianceState = _pDevice->newComputePipelineState(varFn, &svErr);
                    varFn->release();
                }
                if (_pSVGFReprojectState && _pSVGFVarianceState)
                    Con_Printf("SVGF: temporal reprojection + variance estimator compiled\n");
                svLib->release();
            }
        } else {
            Con_Printf("Denoiser: shader compilation failed\n");
        }
    }
    Cvar_RegisterVariable(&vid_rtx);
    Cvar_RegisterVariable(&r_svgf);
    Cvar_RegisterVariable(&r_frameinterp);

    // vid_vsync — off by default to allow uncapped FPS. Writes to the
    // CAMetalLayer's displaySyncEnabled so the change takes effect on
    // the next present without needing a window recreate.
    static cvar_t vid_vsync = {(char*)"vid_vsync", (char*)"0", 1};
    Cvar_RegisterVariable(&vid_vsync);

    // vid_fullscreen — flip into borderless fullscreen. NSWindow handles
    // the native Spaces transition; the MTKView autosizes to follow.
    static cvar_t vid_fullscreen = {(char*)"vid_fullscreen", (char*)"0", 1};
    Cvar_RegisterVariable(&vid_fullscreen);

    // r_rt_split_blas — opt-in split world/entity BLAS path. When off (the
    // default), BuildRTXWorld builds one unified BLAS and wraps it in a
    // 1-instance IAS. When on, the world BLAS caches per map and the
    // entity BLAS rebuilds per frame; both are wrapped in a 2-instance
    // IAS with offsets [0, worldTriCount]. The shader's instanceOffsets
    // buffer abstracts over the two paths so the same shader runs either.
    static cvar_t r_rt_split_blas = {(char*)"r_rt_split_blas", (char*)"0", 1};
    Cvar_RegisterVariable(&r_rt_split_blas);

    // r_restir — opt-in ReSTIR DI over the per-map emissive-triangle
    // list. The shader reservoir-samples 4 candidates per pixel, picks
    // one via target-function RIS (cos/dist²), casts a single shadow
    // ray, and accumulates the chosen triangle's atlas-sampled color
    // into the lighting budget. Off by default because the contribution
    // scale interacts with the existing BSP lightmap baseline and will
    // blow out on some maps until we retune.
    static cvar_t r_restir = {(char*)"r_restir", (char*)"0", 1};
    Cvar_RegisterVariable(&r_restir);


    // Frame Interpolation init is routed through MQ_FrameInterp.m so we
    // don't need MTLFXFrameInterpolator headers in this C++ file. The
    // shim reports availability and — if available — constructs the
    // actual MTLFXFrameInterpolator bound to our display-size output.
    if (MQ_FI_IsAvailable()) {
        _frameInterpolatorAvailable = true;
        _pFrameInterpolator = MQ_FI_Create(_pDevice, w, h, (unsigned long)MTL::PixelFormatBGRA8Unorm);
        if (_pFrameInterpolator) {
            // Allocate the textures Frame Interpolation needs: a previous-
            // frame color buffer we blit the last presented drawable into,
            // and an output texture the interpolator writes the between-
            // frame image to.
            auto* pFIDesc = MTL::TextureDescriptor::texture2DDescriptor(MTL::PixelFormatBGRA8Unorm, w, h, false);
            pFIDesc->setUsage(MTL::TextureUsageShaderWrite | MTL::TextureUsageShaderRead);
            pFIDesc->setStorageMode(MTL::StorageModePrivate);
            _pPrevColorTexture  = _pDevice->newTexture(pFIDesc);
            _pFrameInterpOutput = _pDevice->newTexture(pFIDesc);
            Con_Printf("MetalFX: Frame Interpolation ready (use `r_frameinterp 1` to enable)\n");
        }
    } else {
        Con_Printf("MetalFX: Frame Interpolation unavailable (requires macOS 15+)\n");
    }

    vid_menudrawfn = VID_MenuDraw; vid_menukeyfn = VID_MenuKey;
}

extern "C" void VID_Update(vrect_t *rects) {
    if (!_pPipelineState) return;
    auto* pPool = NS::AutoreleasePool::alloc()->init();

    // Apply vid_vsync / vid_fullscreen changes lazily. Sys_* helpers
    // dispatch to the main thread, so polling once per frame is cheap.
    {
        cvar_t *vs = Cvar_FindVar((char*)"vid_vsync");
        static int lastVsync = -1;
        if (vs) {
            int want = vs->value != 0.0f ? 1 : 0;
            if (want != lastVsync) {
                Sys_SetVsync(want);
                lastVsync = want;
            }
        }
        cvar_t *fs = Cvar_FindVar((char*)"vid_fullscreen");
        static int lastFullscreen = -1;
        if (fs) {
            int want = fs->value != 0.0f ? 1 : 0;
            if (want != lastFullscreen) {
                Sys_SetFullscreen(want);
                lastFullscreen = want;
            }
        }
    }

    BuildRTXWorld();
    if (dispatch_semaphore_wait(_frameSemaphore, dispatch_time(DISPATCH_TIME_NOW, 1000 * NSEC_PER_MSEC)) != 0) { pPool->release(); return; }
    _currentFrame = (_currentFrame + 1) % MaxFramesInFlight;
    auto* pCurrentIdxTex = _pIndexTextures[_currentFrame];
    auto* pDrawable = (CA::MetalDrawable*)Sys_GetNextDrawable(_pMetalLayer);
    if (!pDrawable) { dispatch_semaphore_signal(_frameSemaphore); pPool->release(); return; }
    
    auto* pCmdCompute = _pCommandQueue->commandBuffer();
    auto* pCmdRender = _pCommandQueue->commandBuffer();
    // Label the command buffers so Instruments / Metal Debugger groups
    // work under readable names instead of anonymous buffer IDs.
    pCmdCompute->setLabel(NS::String::string("MQ.RT+Compose",   NS::UTF8StringEncoding));
    pCmdRender->setLabel(NS::String::string("MQ.Composite+HUD", NS::UTF8StringEncoding));
    pCmdCompute->enqueue();
    pCmdRender->enqueue();
    
    static MTL::SharedEvent* _glitchSyncEvent = nullptr;
    static uint64_t _glitchSyncValue = 0;
    if (!_glitchSyncEvent) _glitchSyncEvent = _pDevice->newSharedEvent();
    _glitchSyncValue++;
    
    dispatch_apply(2, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^(size_t threadIndex) {
        if (threadIndex == 0) {
            // --- Thread 0: Compute Pass (Raytracing, Denoising, MetalFX) ---
            auto* pPool1 = NS::AutoreleasePool::alloc()->init();
            if (vid_rtx.value && _pRTComputeState && _pRTInstancedAS) {
                if (_rtBLASEvent && _rtBLASEventValue > 0) {
                    ((void (*)(id, SEL, id, uint64_t))objc_msgSend)((id)pCmdCompute,
                        sel_registerName("encodeWaitForEvent:value:"), (id)_rtBLASEvent, _rtBLASEventValue);
                }
                auto* pCompEnc = pCmdCompute->computeCommandEncoder();
                pCompEnc->setLabel(NS::String::string("RT.Raytrace", NS::UTF8StringEncoding));
                pCompEnc->setComputePipelineState(_pRTComputeState);
                pCompEnc->setTexture(_pRTOutputTexture, 0);
                // Bind the IAS as the scene (always — the shader consumes
                // instance_acceleration_structure now; unified-BLAS path
                // wraps in a 1-instance IAS for that reason).
                pCompEnc->setAccelerationStructure(_pRTInstancedAS, 0);
                // The underlying BLAS the IAS refers to must be reachable
                // by the dispatch, but setAccelerationStructure on the IAS
                // doesn't auto-announce the nested BLASes. Declare each as
                // a used resource so the driver doesn't page them out.
                if (_pRTBLAS)    pCompEnc->useResource(_pRTBLAS,    MTL::ResourceUsageRead);
                if (_pWorldBLAS) pCompEnc->useResource(_pWorldBLAS, MTL::ResourceUsageRead);
                if (_pEntityBLAS) pCompEnc->useResource(_pEntityBLAS, MTL::ResourceUsageRead);
                if (_pTextureAtlas) pCompEnc->setTexture(_pTextureAtlas, 1);
                extern refdef_t r_refdef; extern vec3_t vpn, vright, vup;
                float fOrigin[4] = { r_refdef.vieworg[0], r_refdef.vieworg[1], r_refdef.vieworg[2], 0.0f };
                float fForward[4] = { vpn[0], vpn[1], vpn[2], 0.0f };
                float fRight[4] = { vright[0], vright[1], vright[2], 0.0f };
                float fUp[4] = { vup[0], vup[1], vup[2], 0.0f };
                pCompEnc->setBytes(&fOrigin, 16, 1); pCompEnc->setBytes(&fForward, 16, 2); pCompEnc->setBytes(&fRight, 16, 3); pCompEnc->setBytes(&fUp, 16, 4);

                // --- Populate + bind the RT argument buffer at slot 5 ---
                //
                // A shader with an argument-buffer parameter expects
                // ALL slots in the struct to be populated, even if a
                // given code path doesn't read them. We write each
                // pointer (or a 1-entry scratch for optional/nil
                // resources) and then useResource: annotate the
                // command encoder so the driver pages each buffer into
                // GPU-visible memory for the dispatch.
                static MTL::Buffer* _dummyDynLightBuf = nullptr;
                if (!_dummyDynLightBuf) {
                    GPUDynLight zeros[1] = {{0,0,0,0}};
                    _dummyDynLightBuf = _pDevice->newBuffer(zeros, sizeof(zeros), MTL::ResourceStorageModeShared);
                }
                static MTL::Buffer* _dummyEmissiveBuf = nullptr;
                if (!_dummyEmissiveBuf) {
                    uint32_t zeros[1] = {0u};
                    _dummyEmissiveBuf = _pDevice->newBuffer(zeros, sizeof(zeros), MTL::ResourceStorageModeShared);
                }
                MTL::Buffer* vBuf  = _pRTVertexBuffer;
                MTL::Buffer* iBuf  = _pRTIndexBuffer;
                MTL::Buffer* tBuf  = _pTriTexInfoBuffer;
                MTL::Buffer* dBuf  = _pDynLightBuffer ? _pDynLightBuffer : _dummyDynLightBuf;
                MTL::Buffer* oBuf  = _pInstanceOffsetsBuffer;
                MTL::Buffer* eBuf  = _pEmissiveTriBuffer ? _pEmissiveTriBuffer : _dummyEmissiveBuf;
                if (_pRTArgEncoder && _pRTArgBuffer && vBuf && iBuf && tBuf && oBuf) {
                    _pRTArgEncoder->setArgumentBuffer(_pRTArgBuffer, 0);
                    _pRTArgEncoder->setBuffer(vBuf, 0, 0);
                    _pRTArgEncoder->setBuffer(iBuf, 0, 1);
                    _pRTArgEncoder->setBuffer(tBuf, 0, 2);
                    _pRTArgEncoder->setBuffer(dBuf, 0, 3);
                    _pRTArgEncoder->setBuffer(oBuf, 0, 4);
                    _pRTArgEncoder->setBuffer(eBuf, 0, 5);
                    pCompEnc->setBuffer(_pRTArgBuffer, 0, 5);
                    // The driver must page the underlying buffers for
                    // the dispatch since they're reached only through
                    // the argument buffer pointers.
                    pCompEnc->useResource(vBuf, MTL::ResourceUsageRead);
                    pCompEnc->useResource(iBuf, MTL::ResourceUsageRead);
                    pCompEnc->useResource(tBuf, MTL::ResourceUsageRead);
                    pCompEnc->useResource(dBuf, MTL::ResourceUsageRead);
                    pCompEnc->useResource(oBuf, MTL::ResourceUsageRead);
                    pCompEnc->useResource(eBuf, MTL::ResourceUsageRead);
                }
                pCompEnc->setBytes(&_numActiveLights, sizeof(int), 9);
                float shaderTime = (float)realtime;
                pCompEnc->setBytes(&shaderTime, sizeof(float), 10);
                if (_pRTDepthTexture) pCompEnc->setTexture(_pRTDepthTexture, 2);
                if (_pRTMotionTexture) pCompEnc->setTexture(_pRTMotionTexture, 3);
                pCompEnc->setBytes(&_prevCamOrigin, 16, 11);
                pCompEnc->setBytes(&_prevCamForward, 16, 12);
                pCompEnc->setBytes(&_prevCamRight, 16, 13);
                pCompEnc->setBytes(&_prevCamUp, 16, 14);
                int rtQualityBind = (int)MQ_GetSettings()->rt_quality;
                pCompEnc->setBytes(&rtQualityBind, sizeof(int), 15);
                extern mleaf_t *r_viewleaf;
                int underwaterBind = (r_viewleaf && r_viewleaf->contents <= CONTENTS_WATER
                                      && MQ_GetSettings()->underwater_fx) ? 1 : 0;
                pCompEnc->setBytes(&underwaterBind, sizeof(int), 16);
                // instanceOffsets (was slot 17) and emissiveTris (was
                // slot 18) are now inside the argument buffer at ids 4
                // and 5 — no per-slot bind needed. emissiveCount +
                // useReSTIR remain as scalar setBytes below.
                int emissiveCountBind = (int)_emissiveTriIndices.size();
                pCompEnc->setBytes(&emissiveCountBind, sizeof(int), 19);
                cvar_t *restirCvar = Cvar_FindVar((char*)"r_restir");
                int useRestirBind = (restirCvar && restirCvar->value != 0.0f) ? 1 : 0;
                pCompEnc->setBytes(&useRestirBind, sizeof(int), 20);
                pCompEnc->dispatchThreads(MTL::Size(_pRTOutputTexture->width(), _pRTOutputTexture->height(), 1), MTL::Size(_pRTComputeState->threadExecutionWidth(), _pRTComputeState->maxTotalThreadsPerThreadgroup() / _pRTComputeState->threadExecutionWidth(), 1));
                pCompEnc->endEncoding();
                
                memcpy(_prevCamOrigin, fOrigin, 16);
                memcpy(_prevCamForward, fForward, 16);
                memcpy(_prevCamRight, fRight, 16);
                memcpy(_prevCamUp, fUp, 16);
                _temporalReset = false;
                _frameIndex++;
                
                // SVGF temporal reprojection (scaffolding). Off by default
                // via r_svgf cvar; when enabled, blends the previous frame's
                // denoised output through this frame's motion vectors before
                // the spatial denoiser runs. Skipped on _temporalReset so
                // history noise doesn't leak across map changes.
                if (r_svgf.value != 0.0f && _pSVGFReprojectState && _pSVGFHistoryTexture &&
                    _pSVGFMomentsTexture && _pRTOutputTexture && _pDenoiseScratch &&
                    _pRTMotionTexture && !_temporalReset) {
                    // Pass 1: temporal reprojection (+ moments update).
                    // The moments buffer is read and written as ping-pong
                    // inside a single dispatch; MTL allows this because
                    // reads happen before writes at the same gid.
                    auto* pReEnc = pCmdCompute->computeCommandEncoder();
                    pReEnc->setLabel(NS::String::string("SVGF.Reproject", NS::UTF8StringEncoding));
                    pReEnc->setComputePipelineState(_pSVGFReprojectState);
                    pReEnc->setTexture(_pRTOutputTexture,     0);
                    pReEnc->setTexture(_pSVGFHistoryTexture,  1);
                    pReEnc->setTexture(_pRTMotionTexture,     2);
                    pReEnc->setTexture(_pDenoiseScratch,      3);
                    pReEnc->setTexture(_pSVGFMomentsTexture,  4);
                    pReEnc->setTexture(_pSVGFMomentsTexture,  5);
                    float alpha = 0.85f;
                    pReEnc->setBytes(&alpha, sizeof(float), 0);
                    pReEnc->dispatchThreads(
                        MTL::Size(_pRTOutputTexture->width(), _pRTOutputTexture->height(), 1),
                        MTL::Size(_pSVGFReprojectState->threadExecutionWidth(),
                                  _pSVGFReprojectState->maxTotalThreadsPerThreadgroup() / _pSVGFReprojectState->threadExecutionWidth(), 1));
                    pReEnc->endEncoding();
                    auto* pBlit = pCmdCompute->blitCommandEncoder();
                    pBlit->copyFromTexture(_pDenoiseScratch, _pRTOutputTexture);
                    pBlit->endEncoding();

                    // Pass 2: estimate spatial variance from the moments
                    // buffer. Only needed for r_svgf >= 2 (variance-aware
                    // bilateral modulation); at mode 1 we're done after
                    // reprojection.
                    if (r_svgf.value >= 2.0f && _pSVGFVarianceState && _pSVGFVarianceTexture) {
                        auto* pVarEnc = pCmdCompute->computeCommandEncoder();
                        pVarEnc->setLabel(NS::String::string("SVGF.Variance", NS::UTF8StringEncoding));
                        pVarEnc->setComputePipelineState(_pSVGFVarianceState);
                        pVarEnc->setTexture(_pSVGFMomentsTexture,  0);
                        pVarEnc->setTexture(_pSVGFVarianceTexture, 1);
                        pVarEnc->dispatchThreads(
                            MTL::Size(_pRTOutputTexture->width(), _pRTOutputTexture->height(), 1),
                            MTL::Size(_pSVGFVarianceState->threadExecutionWidth(),
                                      _pSVGFVarianceState->maxTotalThreadsPerThreadgroup() / _pSVGFVarianceState->threadExecutionWidth(), 1));
                        pVarEnc->endEncoding();
                    }
                }

                if (MQ_GetSettings()->neural_denoise && _pRTOutputTexture && _pDenoiseScratch) {
                    int denoiseResult = MQ_CoreML_Denoise((void*)_pRTOutputTexture, (void*)_pDenoiseScratch, _pRTOutputTexture->width(), _pRTOutputTexture->height());
                    if (denoiseResult == 0) {
                        auto* pBlit = pCmdCompute->blitCommandEncoder();
                        pBlit->copyFromTexture(_pDenoiseScratch, _pRTOutputTexture);
                        pBlit->endEncoding();
                    } else if (_pDenoiseState) {
                        // Two passes instead of three; the step-4 pass
                        // was the one painting over pixel-art texel
                        // boundaries and producing the "wrapped in
                        // plastic" look the user noticed.
                        int stepWidths[] = {1, 2};
                        MTL::Texture* readTex = _pRTOutputTexture;
                        MTL::Texture* writeTex = _pDenoiseScratch;
                        const int passCount = 2;
                        for (int pass = 0; pass < passCount; pass++) {
                            auto* pDenEnc = pCmdCompute->computeCommandEncoder();
                            pDenEnc->setLabel(NS::String::string("Denoise.Atrous", NS::UTF8StringEncoding));
                            pDenEnc->setComputePipelineState(_pDenoiseState);
                            pDenEnc->setTexture(readTex, 0);
                            pDenEnc->setTexture(writeTex, 1);
                            pDenEnc->setTexture(_pRTDepthTexture, 2);
                            pDenEnc->setBytes(&stepWidths[pass], sizeof(int), 0);
                            pDenEnc->dispatchThreads(
                                MTL::Size(readTex->width(), readTex->height(), 1),
                                MTL::Size(_pDenoiseState->threadExecutionWidth(),
                                          _pDenoiseState->maxTotalThreadsPerThreadgroup() / _pDenoiseState->threadExecutionWidth(), 1));
                            pDenEnc->endEncoding();
                            MTL::Texture* tmp = readTex; readTex = writeTex; writeTex = tmp;
                        }
                        if (readTex == _pDenoiseScratch) {
                            auto* pBlit = pCmdCompute->blitCommandEncoder();
                            pBlit->copyFromTexture(_pDenoiseScratch, _pRTOutputTexture);
                            pBlit->endEncoding();
                        }
                    }
                }

                // Update SVGF history with the final denoised RT output so
                // the next frame can reproject through it. Only copies when
                // reprojection is armed; otherwise the history texture sits
                // idle.
                if (r_svgf.value != 0.0f && _pSVGFHistoryTexture && _pRTOutputTexture) {
                    auto* pBlit = pCmdCompute->blitCommandEncoder();
                    pBlit->copyFromTexture(_pRTOutputTexture, _pSVGFHistoryTexture);
                    pBlit->endEncoding();
                }

                if (_pTemporalScaler && _pMFXOutputTexture && _pRTDepthTexture && _pRTMotionTexture &&
                    MQ_GetSettings()->metalfx_mode == MQ_METALFX_TEMPORAL) {
                    static const float haltonX[] = {0.5f, 0.25f, 0.75f, 0.125f, 0.625f, 0.375f, 0.875f, 0.0625f};
                    static const float haltonY[] = {0.333f, 0.667f, 0.111f, 0.444f, 0.778f, 0.222f, 0.556f, 0.889f};
                    int jIdx = _frameIndex % 8;
                    _pTemporalScaler->setColorTexture(_pRTOutputTexture);
                    _pTemporalScaler->setDepthTexture(_pRTDepthTexture);
                    _pTemporalScaler->setMotionTexture(_pRTMotionTexture);
                    _pTemporalScaler->setOutputTexture(_pMFXOutputTexture);
                    _pTemporalScaler->setInputContentWidth(_pRTOutputTexture->width());
                    _pTemporalScaler->setInputContentHeight(_pRTOutputTexture->height());
                    _pTemporalScaler->setJitterOffsetX(haltonX[jIdx] - 0.5f);
                    _pTemporalScaler->setJitterOffsetY(haltonY[jIdx] - 0.5f);
                    _pTemporalScaler->setReset(_temporalReset);
                    _pTemporalScaler->encodeToCommandBuffer(pCmdCompute);
                }
            }
            
            ((void (*)(id, SEL, id, uint64_t))objc_msgSend)((id)pCmdCompute, 
                sel_registerName("encodeSignalEvent:value:"), (id)_glitchSyncEvent, _glitchSyncValue);
                
            pCmdCompute->commit();
            pPool1->release();
        } else if (threadIndex == 1) {
            // --- Thread 1: UI Upload & Render Pass (Compositing, Mesh Rasterization) ---
            auto* pPool2 = NS::AutoreleasePool::alloc()->init();
            
            pCurrentIdxTex->replaceRegion(MTL::Region(0, 0, vid.width, vid.height), 0, vid.buffer, vid.rowbytes);
            
            ((void (*)(id, SEL, id, uint64_t))objc_msgSend)((id)pCmdRender, 
                sel_registerName("encodeWaitForEvent:value:"), (id)_glitchSyncEvent, _glitchSyncValue);
                
            auto* pRpd = MTL::RenderPassDescriptor::alloc()->init();
            pRpd->colorAttachments()->object(0)->setTexture(pDrawable->texture()); pRpd->colorAttachments()->object(0)->setLoadAction(MTL::LoadActionDontCare); pRpd->colorAttachments()->object(0)->setStoreAction(MTL::StoreActionStore);
            
            auto* pEnc = pCmdRender->renderCommandEncoder(pRpd);
            pEnc->setRenderPipelineState(_pPipelineState); pEnc->setFragmentTexture(pCurrentIdxTex, 0); pEnc->setFragmentTexture(_pPaletteTexture, 1); pEnc->setFragmentTexture(_pRTOutputTexture, 2); pEnc->setFragmentTexture(_pRTDepthTexture, 3);
            
            struct {
                float screenBlend[4];
                float time;
                float underwater;
                float crt_mode;
                float liquid_glass;
                float resolution[2];
                float ssao_enabled;
                float edr_enabled;
                float chromatic_aberration;
                float high_contrast_hud;
                float hud_band_y;
                float _pad0;
            } postfx;
            memset(&postfx, 0, sizeof(postfx));
            {
                float r = 0, g = 0, b = 0, a = 0;
                for (int j = 0; j < NUM_CSHIFTS; j++) {
                    float a2 = cl.cshifts[j].percent / 255.0f;
                    if (a2 <= 0) continue;
                    a = a + a2 * (1.0f - a);
                    if (a > 0) {
                        float blend = a2 / a;
                        r = r * (1.0f - blend) + cl.cshifts[j].destcolor[0] * blend;
                        g = g * (1.0f - blend) + cl.cshifts[j].destcolor[1] * blend;
                        b = b * (1.0f - blend) + cl.cshifts[j].destcolor[2] * blend;
                    }
                }
                postfx.screenBlend[0] = r / 255.0f;
                postfx.screenBlend[1] = g / 255.0f;
                postfx.screenBlend[2] = b / 255.0f;
                postfx.screenBlend[3] = a > 1.0f ? 1.0f : (a < 0 ? 0 : a);
            }
            postfx.time = (float)realtime;
            extern mleaf_t *r_viewleaf;
            postfx.underwater = (MQ_GetSettings()->underwater_fx && r_viewleaf && r_viewleaf->contents <= CONTENTS_WATER) ? 1.0f : 0.0f;
            postfx.crt_mode = MQ_GetSettings()->crt_mode ? 1.0f : 0.0f;
            postfx.liquid_glass = MQ_GetSettings()->liquid_glass_ui ? 1.0f : 0.0f;
            postfx.resolution[0] = (float)pDrawable->texture()->width();
            postfx.resolution[1] = (float)pDrawable->texture()->height();
            postfx.ssao_enabled = MQ_GetSettings()->ssao_enabled ? 1.0f : 0.0f;
            postfx.edr_enabled = MQ_GetSettings()->edr_enabled ? 1.0f : 0.0f;
            postfx.chromatic_aberration = MQ_GetSettings()->chromatic_aberration ? 1.0f : 0.0f;
            postfx.high_contrast_hud = MQ_GetSettings()->high_contrast_hud ? 1.0f : 0.0f;
            // Aspect-aware HUD band: width of the HUD strip in UV is inverse
            // to display aspect so it stays pixel-consistent on ultrawide.
            // Sbar is 320×48 in internal units; at 4:3 → 0.15, wider → less.
            {
                float aspect = postfx.resolution[0] / postfx.resolution[1];
                float bandHeight = 0.15f * (4.0f / 3.0f) / aspect;
                if (bandHeight < 0.06f) bandHeight = 0.06f;
                if (bandHeight > 0.30f) bandHeight = 0.30f;
                postfx.hud_band_y = 1.0f - bandHeight;
            }
            pEnc->setFragmentBytes(&postfx, sizeof(postfx), 0);
            pEnc->drawPrimitives(MTL::PrimitiveTypeTriangle, (NS::UInteger)0, (NS::UInteger)3);
            
            if (!vid_rtx.value && MQ_GetSettings()->mesh_shaders && _pMeshPipelineState && _worldMeshlets.size() > 0) {
                ((void (*)(id, SEL, id))objc_msgSend)((id)pEnc, sel_registerName("setRenderPipelineState:"), (id)_pMeshPipelineState);
                if (_pRTVertexBuffer) {
                    ((void (*)(id, SEL, id, NS::UInteger, NS::UInteger))objc_msgSend)((id)pEnc, sel_registerName("setVertexBuffer:offset:atIndex:"), (id)_pRTVertexBuffer, 0, 0);
                    ((void (*)(id, SEL, id, NS::UInteger, NS::UInteger))objc_msgSend)((id)pEnc, sel_registerName("setObjectBuffer:offset:atIndex:"), (id)_pRTVertexBuffer, 0, 0);
                    ((void (*)(id, SEL, id, NS::UInteger, NS::UInteger))objc_msgSend)((id)pEnc, sel_registerName("setMeshBuffer:offset:atIndex:"), (id)_pRTVertexBuffer, 0, 0);
                }
                if (_pRTIndexBuffer) {
                    ((void (*)(id, SEL, id, NS::UInteger, NS::UInteger))objc_msgSend)((id)pEnc, sel_registerName("setMeshBuffer:offset:atIndex:"), (id)_pRTIndexBuffer, 0, 1);
                }
                if (_pMeshletBuffer) {
                    ((void (*)(id, SEL, id, NS::UInteger, NS::UInteger))objc_msgSend)((id)pEnc, sel_registerName("setObjectBuffer:offset:atIndex:"), (id)_pMeshletBuffer, 0, 2);
                    ((void (*)(id, SEL, id, NS::UInteger, NS::UInteger))objc_msgSend)((id)pEnc, sel_registerName("setMeshBuffer:offset:atIndex:"), (id)_pMeshletBuffer, 0, 2);
                }
                if (_pTextureAtlas) {
                    ((void (*)(id, SEL, id, NS::UInteger))objc_msgSend)((id)pEnc, sel_registerName("setFragmentTexture:atIndex:"), (id)_pTextureAtlas, 0);
                }

                // Bind mesh-shader uniforms. LOD thresholds are set here
                // so the object shader can cull triangles on distant
                // meshlets; without values other than zero, LOD is
                // disabled (stride = 1 for every meshlet).
                struct {
                    float viewProjection[16];
                    float prevViewProjection[16];
                    float cameraPosition[4];
                    float frustumPlanes[24];
                    float time;
                    uint32_t meshletCount;
                    float lodNearDistance;
                    float lodFarDistance;
                } meshUniforms;
                memset(&meshUniforms, 0, sizeof(meshUniforms));
                // Identity view/projection is acceptable as a placeholder;
                // the object shader only uses cameraPosition and frustum
                // for culling, which we leave wide-open (no culling) by
                // zeroing the planes. LOD kicks in anywhere past 512
                // world units and bottoms out at 4096 units (~50 meters).
                meshUniforms.meshletCount     = (uint32_t)_worldMeshlets.size();
                meshUniforms.lodNearDistance  = 512.0f;
                meshUniforms.lodFarDistance   = 4096.0f;
                extern float r_origin[3];
                meshUniforms.cameraPosition[0] = r_origin[0];
                meshUniforms.cameraPosition[1] = r_origin[1];
                meshUniforms.cameraPosition[2] = r_origin[2];
                meshUniforms.time = (float)realtime;
                ((void (*)(id, SEL, const void*, NS::UInteger, NS::UInteger))objc_msgSend)(
                    (id)pEnc, sel_registerName("setObjectBytes:length:atIndex:"),
                    &meshUniforms, sizeof(meshUniforms), 0);
                ((void (*)(id, SEL, const void*, NS::UInteger, NS::UInteger))objc_msgSend)(
                    (id)pEnc, sel_registerName("setMeshBytes:length:atIndex:"),
                    &meshUniforms, sizeof(meshUniforms), 0);
                ((void (*)(id, SEL, const void*, NS::UInteger, NS::UInteger))objc_msgSend)(
                    (id)pEnc, sel_registerName("setFragmentBytes:length:atIndex:"),
                    &meshUniforms, sizeof(meshUniforms), 0);

                MTL::Size threadgroupsPerGrid = MTL::Size(_worldMeshlets.size(), 1, 1);
                MTL::Size threadsPerObjectThreadgroup = MTL::Size(1, 1, 1);
                MTL::Size threadsPerMeshThreadgroup = MTL::Size(32, 1, 1);
                
                ((void (*)(id, SEL, MTL::Size, MTL::Size, MTL::Size))objc_msgSend)((id)pEnc, 
                    sel_registerName("drawMeshThreadgroups:threadsPerObjectThreadgroup:threadsPerMeshThreadgroup:"), 
                    threadgroupsPerGrid, threadsPerObjectThreadgroup, threadsPerMeshThreadgroup);
            }
            
            pEnc->endEncoding(); pRpd->release();

            // Frame Interpolation path: encode the synthesized middle
            // frame into _pFrameInterpOutput and blit it over the prev-
            // frame buffer so the NEXT frame's interpolator has valid
            // history. This is a simplified single-synthesized-frame
            // pipeline — a 120 Hz display would want two synthesized
            // frames (at t=1/3 and t=2/3), but doubling at t=0.5 is a
            // reasonable first cut that still materially smooths motion.
            if (r_frameinterp.value != 0.0f && _pFrameInterpolator
                && _pPrevColorTexture && _pFrameInterpOutput
                && _pRTMotionTexture && _pRTDepthTexture) {
                int fiRes = MQ_FI_Encode(_pFrameInterpolator, pCmdRender,
                                         (void*)pDrawable->texture(),
                                         (void*)_pPrevColorTexture,
                                         (void*)_pRTMotionTexture,
                                         (void*)_pRTDepthTexture,
                                         (void*)_pFrameInterpOutput,
                                         0.5f);
                if (fiRes == 0) {
                    auto* pBlit = pCmdRender->blitCommandEncoder();
                    pBlit->copyFromTexture(pDrawable->texture(), _pPrevColorTexture);
                    pBlit->endEncoding();
                }
            }

            pCmdRender->presentDrawable(pDrawable);
            pCmdRender->addCompletedHandler([](MTL::CommandBuffer* pCmd) { dispatch_semaphore_signal(_frameSemaphore); });
            pCmdRender->commit();
            pPool2->release();
        }
    });
    
    pPool->release();
}

extern "C" int VID_SetMode(int modenum, unsigned char *palette) { return 1; }
extern "C" void VID_SetPalette(unsigned char *palette) { UpdatePaletteLUT(palette); }
extern "C" void VID_ShiftPalette(unsigned char *palette) { VID_SetPalette(palette); }
extern "C" void VID_HandlePause(qboolean pause) {}
extern "C" void VID_Shutdown(void) {
    // Release module-owned Metal handles that don't participate in the
    // per-frame churn. The per-frame buffers (vertex/index/TriTexInfo/
    // dynLight/BLAS) are managed in BuildRTXWorld's build path and its
    // map-change branch; shutdown just catches the long-lived events and
    // pipelines that would otherwise leak one allocation per process.

    // Serialize the JIT shader cache so next launch's pipelines hit the
    // archive instead of recompiling from source. The file is ~30–200KB
    // depending on what shaders actually ran this session.
    if (_pShaderArchive) {
        NS::Error* err = nullptr;
        auto* url = NS::URL::fileURLWithPath(NS::String::string("id1/quake_shader_cache.bin", NS::UTF8StringEncoding));
        ((void (*)(id, SEL, id, id*))objc_msgSend)((id)_pShaderArchive,
            sel_registerName("serializeToURL:error:"), (id)url, (id*)&err);
        _pShaderArchive->release();
        _pShaderArchive = nullptr;
    }

    if (_blasEvent) { _blasEvent->release(); _blasEvent = nullptr; }
    _rtBLASEvent = nullptr;
    _rtBLASEventValue = 0;
    _blasEventValue = 0;

    if (_pFrameInterpolator) {
        MQ_FI_Release(_pFrameInterpolator);
        _pFrameInterpolator = nullptr;
    }
    if (_pResidencySet) {
        MQ_Residency_Release(_pResidencySet);
        _pResidencySet = nullptr;
    }
    if (_pRTArgEncoder) { _pRTArgEncoder->release(); _pRTArgEncoder = nullptr; }
    if (_pRTArgBuffer)  { _pRTArgBuffer->release();  _pRTArgBuffer  = nullptr; }
    if (_pRTFunction)   { _pRTFunction->release();   _pRTFunction   = nullptr; }
}
extern "C" void D_BeginDirectRect(int x, int y, byte *pbitmap, int width, int height) {}
extern "C" void D_EndDirectRect(int x, int y, int width, int height) {}
extern "C" void VID_WindowResized(CGFloat w, CGFloat h, CGFloat s) { if (_pMetalLayer) _pMetalLayer->setDrawableSize(CGSizeMake(w * s, h * s)); }
