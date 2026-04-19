/**
 * @file MQ_Residency.m
 * @brief MTLResidencySet shim (macOS 15+).
 *
 * vid_metal.cpp creates a handful of long-lived Metal objects — texture
 * atlas, world vertex / index buffers, BLAS — that live across the
 * entire process lifetime. On macOS 15 the driver can be told those
 * should never be paged out by grouping them in an MTLResidencySet and
 * attaching the set to the command queue. This avoids residency
 * recomputation every frame and keeps the pool of candidate evictions
 * small.
 *
 * metal-cpp doesn't wrap MTLResidencySet yet, so this lives as a tiny
 * ObjC shim exposing an opaque handle. The C++ renderer calls through
 * `void*` pointers.
 */

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

extern void Con_Printf(const char *fmt, ...);

void* MQ_Residency_Create(void *devicePtr, const char *label) {
    if (@available(macOS 15.0, *)) {
        id<MTLDevice> device = (__bridge id<MTLDevice>)devicePtr;
        MTLResidencySetDescriptor *desc = [[MTLResidencySetDescriptor alloc] init];
        desc.label = label ? [NSString stringWithUTF8String:label] : @"com.metalquake.residency";
        desc.initialCapacity = 32;
        NSError *err = nil;
        id<MTLResidencySet> set = [device newResidencySetWithDescriptor:desc error:&err];
        if (!set) {
            Con_Printf("Residency: creation failed: %s\n",
                       [[err localizedDescription] UTF8String]);
            return NULL;
        }
        return (__bridge_retained void *)set;
    }
    (void)devicePtr; (void)label;
    return NULL;
}

void MQ_Residency_Release(void *setPtr) {
    if (!setPtr) return;
    if (@available(macOS 15.0, *)) {
        id<MTLResidencySet> set = (__bridge_transfer id<MTLResidencySet>)setPtr;
        set = nil;
        (void)set;
    }
}

void MQ_Residency_AddResource(void *setPtr, void *resourcePtr) {
    if (!setPtr || !resourcePtr) return;
    if (@available(macOS 15.0, *)) {
        id<MTLResidencySet> set = (__bridge id<MTLResidencySet>)setPtr;
        id<MTLAllocation>   res = (__bridge id<MTLAllocation>)resourcePtr;
        [set addAllocation:res];
    }
}

void MQ_Residency_Commit(void *setPtr) {
    if (!setPtr) return;
    if (@available(macOS 15.0, *)) {
        id<MTLResidencySet> set = (__bridge id<MTLResidencySet>)setPtr;
        [set commit];
        [set requestResidency];
    }
}

void MQ_Residency_RemoveAll(void *setPtr) {
    if (!setPtr) return;
    if (@available(macOS 15.0, *)) {
        id<MTLResidencySet> set = (__bridge id<MTLResidencySet>)setPtr;
        [set removeAllAllocations];
    }
}

void MQ_Residency_AttachToQueue(void *queuePtr, void *setPtr) {
    if (!queuePtr || !setPtr) return;
    if (@available(macOS 15.0, *)) {
        id<MTLCommandQueue> q   = (__bridge id<MTLCommandQueue>)queuePtr;
        id<MTLResidencySet> set = (__bridge id<MTLResidencySet>)setPtr;
        [q addResidencySet:set];
    }
}

int MQ_Residency_IsAvailable(void) {
    if (@available(macOS 15.0, *)) return 1;
    return 0;
}
