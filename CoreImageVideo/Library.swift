//
//  Library.swift
//  CoreImageVideo
//
//  Created by Chris Eidhof on 03/04/15.
//  Copyright (c) 2015 objc.io. All rights reserved.
//

import Foundation
import AVFoundation
import GLKit

extension CGAffineTransform {
    
    init(rotatingWithAngle angle: CGFloat) {
        let t = CGAffineTransformMakeRotation(angle)
        self.init(a: t.a, b: t.b, c: t.c, d: t.d, tx: t.tx, ty: t.ty)
        
    }
    init(scaleX sx: CGFloat, scaleY sy: CGFloat) {
        let t = CGAffineTransformMakeScale(sx, sy)
        self.init(a: t.a, b: t.b, c: t.c, d: t.d, tx: t.tx, ty: t.ty)
        
    }
    
    func scale(sx: CGFloat, sy: CGFloat) -> CGAffineTransform {
        return CGAffineTransformScale(self, sx, sy)
    }
    func rotate(angle: CGFloat) -> CGAffineTransform {
        return CGAffineTransformRotate(self, angle)
    }
}


class SampleBufferDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let callback: CMSampleBuffer -> ()
    
    init(_ callback: CMSampleBuffer -> ()) {
        self.callback = callback
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        callback(sampleBuffer)
    }
}

extension AVCaptureDevicePosition {
    var transform: CGAffineTransform {
        switch self {
        case .Front:
            return CGAffineTransform(rotatingWithAngle: -CGFloat(M_PI_2)).scale(1, sy: -1)
        case .Back:
            return CGAffineTransform(rotatingWithAngle: -CGFloat(M_PI_2))
        default:
            return CGAffineTransformIdentity
            
        }
    }
    
    var device: AVCaptureDevice? {
        return AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo).filter {
            $0.position == self
        }.first as? AVCaptureDevice
    }
}


struct SampleBufferSource {
    
    typealias BufferConsumer = (CMSampleBuffer, CGAffineTransform) -> ()
    
    let captureSession: AVCaptureSession
    let delegate: SampleBufferDelegate
    var running: Bool = false {
        didSet {
            if running {
                captureSession.startRunning()
            } else {
                captureSession.stopRunning()
            }
        }
    }
    
    init?(device: AVCaptureDevice, transform: CGAffineTransform, callback: BufferConsumer) {
        captureSession = AVCaptureSession()
        if let deviceInput = AVCaptureDeviceInput(device: device, error: nil) where captureSession.canAddInput(deviceInput) {
            captureSession.addInput(deviceInput)
            let dataOutput = AVCaptureVideoDataOutput()
            dataOutput.alwaysDiscardsLateVideoFrames = true
            dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
            delegate = SampleBufferDelegate { buffer in
                callback(buffer, transform)
            }
            dataOutput.setSampleBufferDelegate(delegate, queue: dispatch_get_main_queue())
            captureSession.addOutput(dataOutput)
            captureSession.commitConfiguration()
            return
        }
        return nil
    }
    
    init?(position: AVCaptureDevicePosition, callback: BufferConsumer) {
        if let camera = position.device {
            self.init(device: camera, transform: position.transform, callback: callback)
            return
        }
        return nil
    }
    
}


func ciImage(buffer: CMSampleBuffer) -> CIImage {
    let imageBuffer = CMSampleBufferGetImageBuffer(buffer)
    return CIImage(CVPixelBuffer: imageBuffer)
}

class CoreImageView: GLKView {
    var image: CIImage? {
        didSet {
            // Calling display() triggers drawRect() to be called
            display()
        }
    }
    let coreImageContext: CIContext
    
    override convenience init(frame: CGRect) {
        let eaglContext = EAGLContext(API: EAGLRenderingAPI.OpenGLES2)
        self.init(frame: frame, context: eaglContext)
    }
    
    override init(frame: CGRect, context eaglContext: EAGLContext!) {
        coreImageContext = CIContext(EAGLContext: eaglContext)
        super.init(frame: frame, context: eaglContext)
        // We will be calling display() directly, hence this needs to be false
        enableSetNeedsDisplay = false
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func drawRect(rect: CGRect) {
        if let img = image {
            let r = bounds
            let scale = self.window?.screen.scale ?? 1.0
            let destRect = CGRectApplyAffineTransform(r, CGAffineTransformMakeScale(scale, scale))
            coreImageContext.drawImage(img, inRect: destRect, fromRect: img.extent())
        }
    }
}