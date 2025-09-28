//
//  main.swift
//  test-raytracing-swft
//
//  Created by Archie Maclean on 27/09/2025.
//

// References:
// - Apple ray-tracing example: https://developer.apple.com/documentation/metal/accelerating-ray-tracing-using-metal
// - Compute shaders in Swift: https://flexmonkey.blogspot.com/2014/10/metal-kernel-functions-compute-shaders.html
// - Acceleration structure creation/ray tracing: https://developer.apple.com/videos/play/wwdc2023/10128/

import Foundation
import MetalKit


// Output buffer type of raytracing shader
typealias OutputType = Float32

// ======================================================================
// Runtime options
// ======================================================================

let rayCount = 20_000
let triangleCount = 3_000
let printOutput = false
let capture = false

// ======================================================================
// Metal objects for accessing the GPU device
// ======================================================================

if (capture) {
    startCapture()
}

// TODO: ensure that the device supports raytracing (as per the example code)
let device: MTLDevice = MTLCreateSystemDefaultDevice()!
let library = device.makeDefaultLibrary()!
let queue = device.makeCommandQueue()!
let commandBuffer = queue.makeCommandBuffer()!
let commandEncoder = commandBuffer.makeComputeCommandEncoder()!

// ======================================================================
// Create the shader pipeline - single function ray_trace_to_triangle
// ======================================================================

let fn = library.makeFunction(name: "ray_trace_to_triangle")!
let pipelineState = try! device.makeComputePipelineState(function: fn)
commandEncoder.setComputePipelineState(pipelineState)

// ======================================================================
// Create the output of the shader pipeline - buffer of int32s
// ======================================================================

let outArray: Array<OutputType> = Array.init(repeating: 0, count: rayCount)
let outBuffer = device.makeBuffer(bytes: outArray, length: MemoryLayout<OutputType>.stride * outArray.count)!
commandEncoder.setBuffer(outBuffer, offset: 0, index: 0)

// ======================================================================
// Create the input to the shader pipleline - single MTLAccelerationStructure
// ======================================================================

print("building geometry")

// Geometry creation:
// - Create an Acceleration Descriptor
//  - Descriptor contains one or more Geometry Descriptors
// - Allocate the Acceleration Structure
// - Build the Acceleration Structure

// Step 1. Create the acceleration descriptor

// Geometry descriptor
var geometryDescriptors: [MTLAccelerationStructureGeometryDescriptor] = []

for _ in 0..<triangleCount {
    let triangleDescriptor = MTLAccelerationStructureTriangleGeometryDescriptor()
    let triangleVertices: [MTLPackedFloat3] = [
        MTLPackedFloat3Make(Float.random(in: -100..<100), Float.random(in: -100..<100), Float.random(in: -100..<100)),
        MTLPackedFloat3Make(Float.random(in: -100..<100), Float.random(in: -100..<100), Float.random(in: -100..<100)),
        MTLPackedFloat3Make(Float.random(in: -100..<100), Float.random(in: -100..<100), Float.random(in: -100..<100)),
    ]
    triangleDescriptor.vertexBuffer = device.makeBuffer(bytes: triangleVertices, length: triangleVertices.count * MemoryLayout<MTLPackedFloat3>.stride);
    triangleDescriptor.vertexStride = MemoryLayout<MTLPackedFloat3>.stride
    triangleDescriptor.triangleCount = 1
    
    geometryDescriptors.append(triangleDescriptor)
}

// Acceleration descriptor
let accelerationDescriptor = MTLPrimitiveAccelerationStructureDescriptor()
accelerationDescriptor.geometryDescriptors = geometryDescriptors

// Step 2. Allocate the Acceleration Structure

let sizes: MTLAccelerationStructureSizes = device.accelerationStructureSizes(descriptor: accelerationDescriptor)

let heapAllocationSize: MTLSizeAndAlign = device.heapAccelerationStructureSizeAndAlign(size: sizes.accelerationStructureSize)
let heapDescriptor = MTLHeapDescriptor()
heapDescriptor.size = heapAllocationSize.size

let heap = device.makeHeap(descriptor: heapDescriptor)!
let accelerationStructure = heap.makeAccelerationStructure(size: heapAllocationSize.size)!

commandEncoder.useHeap(heap)

let scratchBuffer = device.makeBuffer(length: sizes.buildScratchBufferSize, options: .storageModePrivate)!

// Step 3. Build the acceleration structure
let accelerationCommandBuffer = queue.makeCommandBuffer()!
let accelerationCommandEncoder = accelerationCommandBuffer.makeAccelerationStructureCommandEncoder()!
accelerationCommandEncoder.useHeap(heap)
accelerationCommandEncoder.build(accelerationStructure: accelerationStructure, descriptor: accelerationDescriptor, scratchBuffer: scratchBuffer, scratchBufferOffset: 0)
accelerationCommandEncoder.endEncoding()
accelerationCommandBuffer.commit()
accelerationCommandBuffer.waitUntilCompleted()

// Add the resulting acceleration structure to the kernel input, as a buffer at index 1
commandEncoder.setAccelerationStructure(accelerationStructure, bufferIndex: 1)

// ======================================================================
// Add a dispatch command to the encoder, which runs the pipeline
// ======================================================================

print("raytracing")

let startInstant = ContinuousClock().now

// TODO: how do these affect the performance
// https://developer.apple.com/documentation/metal/creating-threads-and-threadgroups
// https://developer.apple.com/documentation/metal/calculating-threadgroup-and-grid-sizes
let threadGroupCount = MTLSizeMake(1, 1, 1)
let threadGroups = MTLSizeMake(rayCount, 1, 1)
commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)

// ======================================================================
// Submit the command queue to the GPU and wait for completion
// ======================================================================

commandEncoder.endEncoding()
commandBuffer.commit()
commandBuffer.waitUntilCompleted()

print(ContinuousClock().now - startInstant)

if (capture) {
    stopCapture()
}

// ======================================================================
// Print out the resulting buffer values
// ======================================================================

if (printOutput) {
    printBufferValues(buffer: outBuffer)
}

// ======================================================================
// Helper functions from the Internet (thank you Internet)
// ======================================================================

// https://stackoverflow.com/a/77550857
func printBufferValues(buffer: MTLBuffer) {
    let pointer = buffer.contents().assumingMemoryBound(to: OutputType.self)
    let bufferValues = UnsafeBufferPointer(start: pointer, count: buffer.length / MemoryLayout<OutputType>.stride)
    print(Array(bufferValues))
}

// https://stackoverflow.com/a/73239520
func startCapture() {
    // GPU we want to use, use MTLCopyAllDevices in CLI utilities
    let captureDescriptor = MTLCaptureDescriptor()
    captureDescriptor.captureObject = MTLCopyAllDevices().first!
    // destination is developerTools by default
    try? MTLCaptureManager.shared().startCapture(with: captureDescriptor)
}

// https://stackoverflow.com/a/73239520
func stopCapture() {
    MTLCaptureManager.shared().stopCapture()
}
