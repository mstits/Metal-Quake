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

// Previous frame camera state for motion vector generation
static float _prevCamOrigin[4] = {0};
static float _prevCamForward[4] = {0};
static float _prevCamRight[4] = {0};
static float _prevCamUp[4] = {0};
static bool _temporalReset = true; // Reset on first frame / map change
static int _frameIndex = 0; // For jitter pattern

// Async BLAS event synchronization
static MTL::SharedEvent* _rtBLASEvent = nullptr;
static uint64_t _rtBLASEventValue = 0;
struct GPUDynLight {
    float x, y, z, radius;
};
static int _numActiveLights = 0;

struct TriTexInfo {
    float atlas_u, atlas_v;    // atlas offset (normalized)
    float atlas_w, atlas_h;    // atlas region size (normalized)
    float tex_w, tex_h;        // original texture size (pixels)
    float pad0, pad1;
};

static std::vector<RTVertex> _worldVertices;
static std::vector<uint32_t> _worldIndices;
static std::vector<TriTexInfo> _worldTriTexInfos;
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
    // Comprehensive BSP validity check — catches freed/partial models
    if (!cl.worldmodel->surfaces || !cl.worldmodel->edges ||
        !cl.worldmodel->vertexes || !cl.worldmodel->texinfo ||
        cl.worldmodel->numsurfaces <= 0 || cl.worldmodel->numvertexes <= 0 ||
        cl.worldmodel->name[0] != 'm') return;
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
    const int MAX_ATLAS_WIDTH = 2048;
    
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
                        uint32_t r = pal[palIdx * 3 + 0];
                        uint32_t g = pal[palIdx * 3 + 1];
                        uint32_t b = pal[palIdx * 3 + 2];
                        pixelPtr[ay * aw + ax] = r | (g << 8) | (b << 16) | 0xFF000000;
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
                    atlasPixels[py * aw + px] = r | (g << 8) | (b << 16) | 0xFF000000;
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
    auto* atlasDesc = MTL::TextureDescriptor::texture2DDescriptor(MTL::PixelFormatRGBA8Unorm, aw, ah, false);
    _pTextureAtlas = _pDevice->newTexture(atlasDesc);
    _pTextureAtlas->replaceRegion(MTL::Region(0, 0, aw, ah), 0, atlasPixels.data(), aw * 4);
    
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
    if (_pRTVertexBuffer) _pRTVertexBuffer->release();
    if (_pRTIndexBuffer) _pRTIndexBuffer->release();
    if (_pRTBLAS) _pRTBLAS->release();
    if (_pRTInstanceBuffer) { _pRTInstanceBuffer->release(); _pRTInstanceBuffer = nullptr; }
    if (_pRTInstancedAS) { _pRTInstancedAS->release(); _pRTInstancedAS = nullptr; }
    if (_pTriTexInfoBuffer) _pTriTexInfoBuffer->release();
    if (_pDynLightBuffer) _pDynLightBuffer->release();
    
    // Guard against empty geometry (can happen during map transitions)
    if (frameVertices.empty() || frameIndices.empty() || frameIndices.size() < 3) {
        _pRTVertexBuffer = nullptr; _pRTIndexBuffer = nullptr;
        _pRTBLAS = nullptr; _pTriTexInfoBuffer = nullptr; _pDynLightBuffer = nullptr;
        return;
    }
    
    _pRTVertexBuffer = _pDevice->newBuffer(frameVertices.data(), frameVertices.size() * sizeof(RTVertex), MTL::ResourceStorageModeShared);
    _pRTIndexBuffer = _pDevice->newBuffer(frameIndices.data(), frameIndices.size() * sizeof(uint32_t), MTL::ResourceStorageModeShared);
    _rtIndexCount = (uint32_t)frameIndices.size();
    
    auto* geomDesc = MTL::AccelerationStructureTriangleGeometryDescriptor::alloc()->init();
    geomDesc->setVertexBuffer(_pRTVertexBuffer); geomDesc->setVertexStride(sizeof(RTVertex));
    geomDesc->setIndexBuffer(_pRTIndexBuffer); geomDesc->setIndexType(MTL::IndexTypeUInt32);
    geomDesc->setTriangleCount(_rtIndexCount / 3);
    
    auto* accelDesc = MTL::PrimitiveAccelerationStructureDescriptor::alloc()->init();
    accelDesc->setGeometryDescriptors(NS::Array::array((NS::Object*)geomDesc));
    MTL::AccelerationStructureSizes sizes = _pDevice->accelerationStructureSizes(accelDesc);
    _pRTBLAS = _pDevice->newAccelerationStructure(sizes.accelerationStructureSize);
    auto* scratchBuffer = _pDevice->newBuffer(sizes.buildScratchBufferSize, MTL::ResourceStorageModePrivate);
    
    // Async BLAS build: use a dedicated command buffer with GPU event sync
    // This avoids blocking the CPU while GPU builds the acceleration structure
    auto* blasCmdBuf = _pCommandQueue->commandBuffer();
    blasCmdBuf->setLabel(NS::String::string("BLAS Build", NS::UTF8StringEncoding));
    auto* accelEnc = blasCmdBuf->accelerationStructureCommandEncoder();
    accelEnc->buildAccelerationStructure(_pRTBLAS, accelDesc, scratchBuffer, 0);
    accelEnc->endEncoding();
    
    // Signal shared event when BLAS build completes — RT compute will wait on this
    static MTL::SharedEvent* _blasEvent = nullptr;
    static uint64_t _blasEventValue = 0;
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

        fragment float4 fragmentMain(VertexOut in [[stage_in]],
                                   texture2d<uint> indexTex [[texture(0)]],
                                   texture2d<float> paletteTex [[texture(1)]],
                                   texture2d<float> rtTex [[texture(2)]],
                                   texture2d<float> depthTex [[texture(3)]],
                                   constant float4& screenBlend [[buffer(0)]]) {
            if (in.texCoord.x > 1.0 || in.texCoord.y > 1.0) discard_fragment();
            
            // 1. Get base color
            float3 color = getPixelColor(in.texCoord, indexTex, paletteTex, rtTex);
            
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
                float bright = max(lum - 0.75, 0.0); // Only bloom very bright areas
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
                float focusDepth = depthTex.sample(depthSamp, float2(0.5, 0.5)).r; // Center point autofocus
                
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
            
            // 7. Screen Blends (damage flashes, underwater, powerups)
            if (screenBlend.w > 0.001) {
                color = mix(color, screenBlend.rgb, screenBlend.w);
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
    auto* pFragFn = pLib->newFunction(NS::String::string("fragmentMain", UTF8StringEncoding));
    auto* pDesc = MTL::RenderPipelineDescriptor::alloc()->init();
    pDesc->setVertexFunction(pVertexFn); pDesc->setFragmentFunction(pFragFn);
    pDesc->colorAttachments()->object(0)->setPixelFormat(MTL::PixelFormatBGRA8Unorm);
    _pPipelineState = _pDevice->newRenderPipelineState(pDesc, &pError);
    pVertexFn->release(); pFragFn->release();

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

        kernel void raytraceMain(uint2 tid [[thread_position_in_grid]],
            texture2d<float, access::write> outTexture [[texture(0)]],
            texture2d<float, access::read> atlasTexture [[texture(1)]],
            primitive_acceleration_structure scene [[buffer(0)]],
            constant float4& camOrigin [[buffer(1)]],
            constant float4& camForward [[buffer(2)]],
            constant float4& camRight [[buffer(3)]],
            constant float4& camUp [[buffer(4)]],
            device const RTVertex* vertices [[buffer(5)]],
            device const uint* indices [[buffer(6)]],
            device const TriTexInfo* triTexInfos [[buffer(7)]],
            device const GPUDynLight* dynLights [[buffer(8)]],
            constant int& numLights [[buffer(9)]],
            constant float& time [[buffer(10)]],
            texture2d<float, access::write> depthTexture [[texture(2)]],
            texture2d<float, access::write> motionTexture [[texture(3)]],
            constant float4& prevCamOrigin [[buffer(11)]],
            constant float4& prevCamForward [[buffer(12)]],
            constant float4& prevCamRight [[buffer(13)]],
            constant float4& prevCamUp [[buffer(14)]])
        {
            if (tid.x >= outTexture.get_width() || tid.y >= outTexture.get_height()) return;
            float2 uv = (float2(tid) / float2(outTexture.get_width(), outTexture.get_height())) * 2.0 - 1.0;
            uv.y = -uv.y; uv.x *= (float)outTexture.get_width() / (float)outTexture.get_height();

            ray r;
            r.origin = camOrigin.xyz;
            r.direction = normalize(camForward.xyz + uv.x * camRight.xyz + uv.y * camUp.xyz);
            r.min_distance = 0.1;
            r.max_distance = 100000.0;

            intersector<triangle_data> isect;
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

            TriTexInfo tti = triTexInfos[primId];
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
                    TriTexInfo rtti = triTexInfos[rPrim];
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
                    // Water — tint texture with teal, mix strongly with reflection
                    float3 tint = float3(0.4, 0.75, 0.8);
                    float caustic = (sin(hitPos.x * 0.15 + time * 2.0) * sin(hitPos.y * 0.15 + time * 1.7) + 1.0) * 0.08;
                    baseColor = mix(texBase * tint * (0.6 + warp * 0.4) + caustic, reflColor, 0.6);
                } else if (liquidType < 2.5) {
                    // Lava — emissive, weak reflection
                    float pulse = sin(time * 2.5 + hitPos.x * 0.06 + hitPos.y * 0.04) * 0.25 + 0.75;
                    float3 hotTint = float3(1.2, 0.6, 0.2);
                    float hotSpot = pow(warp, 2.0) * pulse;
                    baseColor = mix(texBase * hotTint * (0.5 + hotSpot * 0.8) + float3(hotSpot * 0.3, hotSpot * 0.1, 0), reflColor, 0.15);
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

            ray shadowRay;
            shadowRay.origin = hitPos + N * 0.1;
            shadowRay.direction = keyDir;
            shadowRay.min_distance = 0.1;
            shadowRay.max_distance = 2000.0;
            float shadowTerm = (isect.intersect(shadowRay, scene).type == intersection_type::triangle) ? 0.1 : 1.0;

            // Blend BSP lightmap with directional fill for depth
            float dirContrib = keyDiffuse * shadowTerm * 0.8;
            float totalLight = max(bspLight * 2.5 + dirContrib, 0.25); // Higher ambient ambient clamp
            float3 warmTint = mix(float3(1.0, 0.95, 0.85), float3(1.0), 0.5);
            float3 lighting = warmTint * totalLight;
            
            // True Emissive Surfaces (Base material glow)
            float primaryLum = dot(baseColor, float3(0.333));
            bool isEmissive = (baseColor.r > 0.7 && baseColor.g < 0.2 && baseColor.b < 0.2) || // Pure Red (Lava)
                              (baseColor.b > 0.7 && baseColor.r < 0.3 && baseColor.g < 0.3) || // Pure Blue (Teleporter/Quad)
                              (primaryLum > 0.85); // High intensity (Light fixtures)
            if (isEmissive) {
                lighting = baseColor * 2.0; // Glow cleanly without blowing out the accumulator
            }
            
            // PBR Specularity based on texture luminance
            float baseLum = dot(baseColor, float3(0.333));
            float specExp = mix(8.0, 64.0, baseLum); // Brighter = sharper highlight
            float3 viewDir = normalize(camOrigin.xyz - hitPos);
            float3 halfVector = normalize(keyDir + viewDir);
            float specTerm = pow(max(dot(N, halfVector), 0.0), specExp) * shadowTerm * baseLum * 0.4;
            lighting += float3(specTerm);

            // === Stochastic Path Tracing GI ===
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
                    TriTexInfo btti = triTexInfos[bPrim];
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

            float3 color = baseColor * lighting;

            // Distance fog
            float fog = saturate(dist / 5000.0);
            color = mix(color, float3(0.20, 0.17, 0.14), fog * fog);

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
        pRTFn->release(); pRTLib->release();
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
static void VID_MenuDraw(void) {
    extern cvar_t sensitivity;
    extern cvar_t sv_aim;
    Draw_String(72, 32, (char*)"Video Options (Metal)");
    const int itemY[] = { 64, 76, 88, 100, 120 };
    const char* itemLabels[] = { "Resolution:", "Raytracing:", "Sensitivity:", "Auto-aim:", "Apply" };
    for (int i = 0; i < 5; i++) {
        if (i == _vidMenuCursor) Draw_Character(56, itemY[i], 12 + ((int)(realtime * 4) & 1));
        Draw_String(72, itemY[i], (char*)itemLabels[i]);
    }
    Draw_String(168, 64, (char*)vid_modes[vid_mode]);
    Draw_String(168, 76, (char*)(vid_rtx.value ? "ON" : "OFF"));
    char sensStr[16]; snprintf(sensStr, sizeof(sensStr), "%.1f", sensitivity.value);
    Draw_String(168, 88, sensStr);
    Draw_String(168, 100, (char*)(sv_aim.value < 1.0 ? "ON" : "OFF"));
}

static void VID_MenuKey(int key) {
    extern cvar_t sensitivity;
    extern cvar_t sv_aim;
    if (key == K_ESCAPE) { 
        extern keydest_t key_dest; extern int m_state;
        key_dest = key_game; m_state = 0;
        return; 
    }
    if (key == K_UPARROW) { _vidMenuCursor--; if (_vidMenuCursor < 0) _vidMenuCursor = 4; }
    else if (key == K_DOWNARROW) { _vidMenuCursor++; if (_vidMenuCursor > 4) _vidMenuCursor = 0; }
    if (_vidMenuCursor == 0) {
        if (key == K_LEFTARROW) { vid_mode--; if (vid_mode < 0) vid_mode = 4; }
        else if (key == K_RIGHTARROW) { vid_mode++; if (vid_mode > 4) vid_mode = 0; }
    } else if (_vidMenuCursor == 1) {
        if (key == K_LEFTARROW || key == K_RIGHTARROW || key == K_ENTER) Cvar_SetValue("vid_rtx", vid_rtx.value ? 0 : 1);
    } else if (_vidMenuCursor == 2) {
        if (key == K_LEFTARROW) { float s = sensitivity.value - 0.5; if (s < 1.0) s = 1.0; Cvar_SetValue("sensitivity", s); }
        else if (key == K_RIGHTARROW) { float s = sensitivity.value + 0.5; if (s > 20.0) s = 20.0; Cvar_SetValue("sensitivity", s); }
    } else if (_vidMenuCursor == 3) {
        if (key == K_LEFTARROW || key == K_RIGHTARROW || key == K_ENTER) {
            Cvar_SetValue("sv_aim", sv_aim.value < 1.0 ? 1.0 : 0.93);
        }
    } else if (_vidMenuCursor == 4) {
        if (key == K_ENTER) Sys_SetWindowSize(vid_mode_ws[vid_mode], vid_mode_hs[vid_mode]);
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
    BuildPipeline(); _frameSemaphore = dispatch_semaphore_create(MaxFramesInFlight);
    _pMetalLayer = (CA::MetalLayer*)Sys_CreateWindow(w, h, _pDevice);
    auto* pTexDesc = MTL::TextureDescriptor::texture2DDescriptor(MTL::PixelFormatR8Uint, vid.width, vid.height, false);
    pTexDesc->setUsage(MTL::TextureUsageShaderRead); pTexDesc->setStorageMode(MTL::StorageModeShared);
    for (int j = 0; j < MaxFramesInFlight; ++j) _pIndexTextures[j] = _pDevice->newTexture(pTexDesc);
    // RT output at 2x internal resolution for sharper raytracing
    int rtW = vid.width * 2, rtH = vid.height * 2;
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
    
    float sigmaColor = 0.1;  // Color similarity threshold
    float sigmaDepth = 0.05; // Depth similarity threshold
    
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
    
    output.write(sumColor / max(sumWeight, 0.0001), gid);
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
        } else {
            Con_Printf("Denoiser: shader compilation failed\n");
        }
    }
    Cvar_RegisterVariable(&vid_rtx); vid_menudrawfn = VID_MenuDraw; vid_menukeyfn = VID_MenuKey;
}

extern "C" void VID_Update(vrect_t *rects) {
    if (!_pPipelineState) return;
    auto* pPool = NS::AutoreleasePool::alloc()->init();
    BuildRTXWorld();
    if (dispatch_semaphore_wait(_frameSemaphore, dispatch_time(DISPATCH_TIME_NOW, 1000 * NSEC_PER_MSEC)) != 0) { pPool->release(); return; }
    _currentFrame = (_currentFrame + 1) % MaxFramesInFlight;
    auto* pCurrentIdxTex = _pIndexTextures[_currentFrame];
    pCurrentIdxTex->replaceRegion(MTL::Region(0, 0, vid.width, vid.height), 0, vid.buffer, vid.rowbytes);
    auto* pDrawable = (CA::MetalDrawable*)Sys_GetNextDrawable(_pMetalLayer);
    if (!pDrawable) { dispatch_semaphore_signal(_frameSemaphore); pPool->release(); return; }
    auto* pCmd = _pCommandQueue->commandBuffer();
    if (vid_rtx.value && _pRTComputeState && _pRTBLAS) {
        // GPU-side wait: ensure BLAS build is complete before ray tracing
        if (_rtBLASEvent && _rtBLASEventValue > 0) {
            ((void (*)(id, SEL, id, uint64_t))objc_msgSend)((id)pCmd, 
                sel_registerName("encodeWaitForEvent:value:"), (id)_rtBLASEvent, _rtBLASEventValue);
        }
        auto* pCompEnc = pCmd->computeCommandEncoder();
        pCompEnc->setComputePipelineState(_pRTComputeState); pCompEnc->setTexture(_pRTOutputTexture, 0); pCompEnc->setAccelerationStructure(_pRTBLAS, 0);
        if (_pTextureAtlas) pCompEnc->setTexture(_pTextureAtlas, 1);
        extern refdef_t r_refdef; extern vec3_t vpn, vright, vup;
        float fOrigin[4] = { r_refdef.vieworg[0], r_refdef.vieworg[1], r_refdef.vieworg[2], 0.0f };
        float fForward[4] = { vpn[0], vpn[1], vpn[2], 0.0f };
        float fRight[4] = { vright[0], vright[1], vright[2], 0.0f };
        float fUp[4] = { vup[0], vup[1], vup[2], 0.0f };
        pCompEnc->setBytes(&fOrigin, 16, 1); pCompEnc->setBytes(&fForward, 16, 2); pCompEnc->setBytes(&fRight, 16, 3); pCompEnc->setBytes(&fUp, 16, 4);
        pCompEnc->setBuffer(_pRTVertexBuffer, 0, 5); pCompEnc->setBuffer(_pRTIndexBuffer, 0, 6);
        if (_pTriTexInfoBuffer) pCompEnc->setBuffer(_pTriTexInfoBuffer, 0, 7);
        if (_pDynLightBuffer) pCompEnc->setBuffer(_pDynLightBuffer, 0, 8);
        else {
            GPUDynLight dummy = {0,0,0,0};
            pCompEnc->setBytes(&dummy, sizeof(dummy), 8);
        }
        pCompEnc->setBytes(&_numActiveLights, sizeof(int), 9);
        float shaderTime = (float)realtime;
        pCompEnc->setBytes(&shaderTime, sizeof(float), 10);
        // MetalFX temporal: bind depth + motion textures
        if (_pRTDepthTexture) pCompEnc->setTexture(_pRTDepthTexture, 2);
        if (_pRTMotionTexture) pCompEnc->setTexture(_pRTMotionTexture, 3);
        // Previous frame camera for motion vectors
        pCompEnc->setBytes(&_prevCamOrigin, 16, 11);
        pCompEnc->setBytes(&_prevCamForward, 16, 12);
        pCompEnc->setBytes(&_prevCamRight, 16, 13);
        pCompEnc->setBytes(&_prevCamUp, 16, 14);
        pCompEnc->dispatchThreads(MTL::Size(_pRTOutputTexture->width(), _pRTOutputTexture->height(), 1), MTL::Size(_pRTComputeState->threadExecutionWidth(), _pRTComputeState->maxTotalThreadsPerThreadgroup() / _pRTComputeState->threadExecutionWidth(), 1));
        pCompEnc->endEncoding();
        // Save current camera as previous for next frame's motion vectors
        memcpy(_prevCamOrigin, fOrigin, 16);
        memcpy(_prevCamForward, fForward, 16);
        memcpy(_prevCamRight, fRight, 16);
        memcpy(_prevCamUp, fUp, 16);
        _temporalReset = false;
        _frameIndex++;
        
        // GPU bilateral denoiser — multi-pass À-trous wavelet filter
        // 3 iterations at step widths 1, 2, 4 for multi-scale edge-aware denoising
        if (_pDenoiseState && _pDenoiseScratch && MQ_GetSettings()->neural_denoise && _pRTOutputTexture) {
            int stepWidths[] = {1, 2, 4};
            MTL::Texture* readTex = _pRTOutputTexture;
            MTL::Texture* writeTex = _pDenoiseScratch;
            for (int pass = 0; pass < 3; pass++) {
                auto* pDenEnc = pCmd->computeCommandEncoder();
                pDenEnc->setComputePipelineState(_pDenoiseState);
                pDenEnc->setTexture(readTex, 0);   // input
                pDenEnc->setTexture(writeTex, 1);   // output
                pDenEnc->setTexture(_pRTDepthTexture, 2); // depth for edge-stop
                pDenEnc->setBytes(&stepWidths[pass], sizeof(int), 0);
                pDenEnc->dispatchThreads(
                    MTL::Size(readTex->width(), readTex->height(), 1),
                    MTL::Size(_pDenoiseState->threadExecutionWidth(),
                              _pDenoiseState->maxTotalThreadsPerThreadgroup() / _pDenoiseState->threadExecutionWidth(), 1));
                pDenEnc->endEncoding();
                // Ping-pong
                MTL::Texture* tmp = readTex; readTex = writeTex; writeTex = tmp;
            }
            // If final result is in scratch, blit back to RT output
            if (readTex == _pDenoiseScratch) {
                auto* pBlit = pCmd->blitCommandEncoder();
                pBlit->copyFromTexture(_pDenoiseScratch, _pRTOutputTexture);
                pBlit->endEncoding();
            }
        }
    }
    auto* pRpd = MTL::RenderPassDescriptor::alloc()->init();
    // Render directly into the drawable — GPU texture sampling upscales 320x240 → 640x480
    pRpd->colorAttachments()->object(0)->setTexture(pDrawable->texture()); pRpd->colorAttachments()->object(0)->setLoadAction(MTL::LoadActionDontCare); pRpd->colorAttachments()->object(0)->setStoreAction(MTL::StoreActionStore);
    auto* pEnc = pCmd->renderCommandEncoder(pRpd);
    pEnc->setRenderPipelineState(_pPipelineState); pEnc->setFragmentTexture(pCurrentIdxTex, 0); pEnc->setFragmentTexture(_pPaletteTexture, 1); pEnc->setFragmentTexture(_pRTOutputTexture, 2); pEnc->setFragmentTexture(_pRTDepthTexture, 3);
    // Compute screen blend from Quake's cshift system
    float screenBlend[4] = {0, 0, 0, 0};
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
        screenBlend[0] = r / 255.0f;
        screenBlend[1] = g / 255.0f;
        screenBlend[2] = b / 255.0f;
        screenBlend[3] = a > 1.0f ? 1.0f : (a < 0 ? 0 : a);
    }
    pEnc->setFragmentBytes(screenBlend, sizeof(screenBlend), 0);
    pEnc->drawPrimitives(MTL::PrimitiveTypeTriangle, (NS::UInteger)0, (NS::UInteger)3);
    pEnc->endEncoding(); pRpd->release();
    pCmd->presentDrawable(pDrawable); pCmd->addCompletedHandler([](MTL::CommandBuffer* pCmd) { dispatch_semaphore_signal(_frameSemaphore); });
    pCmd->commit(); pPool->release();
}

extern "C" int VID_SetMode(int modenum, unsigned char *palette) { return 1; }
extern "C" void VID_SetPalette(unsigned char *palette) { UpdatePaletteLUT(palette); }
extern "C" void VID_ShiftPalette(unsigned char *palette) { VID_SetPalette(palette); }
extern "C" void VID_HandlePause(qboolean pause) {}
extern "C" void VID_Shutdown(void) {}
extern "C" void D_BeginDirectRect(int x, int y, byte *pbitmap, int width, int height) {}
extern "C" void D_EndDirectRect(int x, int y, int width, int height) {}
extern "C" void VID_WindowResized(CGFloat w, CGFloat h, CGFloat s) { if (_pMetalLayer) _pMetalLayer->setDrawableSize(CGSizeMake(w * s, h * s)); }
