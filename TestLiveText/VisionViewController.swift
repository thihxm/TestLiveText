//
//  VisionViewController.swift
//  TestLiveText
//
//  Created by Thiago Medeiros on 01/09/21.
//

import AVFoundation
import UIKit
import Vision

class VisionViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var delegate: TextFoundDelegate?
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!

    private var recognizedTextBoxLayer: CALayer?
    
    private let videoDataOutput = AVCaptureVideoDataOutput()
    
    var recognizedText = ""
    
    convenience init(text: String) {
        self.init()
        self.recognizedText = text
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // MARK: Setup camera input
        self.captureSession = AVCaptureSession()
        self.captureSession.beginConfiguration()
        
        // Reduces video quality to medium
        // captureSession.sessionPreset = .medium
        
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            fatalError("no back camera")
        }

        guard let backInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            fatalError("could not create input device from back camera")
        }

        guard self.captureSession.canAddInput(backInput) else {
            fatalError("could not add back camera input to capture session")
        }
        
        self.captureSession.addInput(backInput)
        
        // MARK: Setup video output
        self.videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        let videoQueue = DispatchQueue(label: "camera_frame_processing_queue", qos: .userInteractive)
        self.videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)

        if self.captureSession.canAddOutput(self.videoDataOutput) == true {
            self.captureSession.addOutput(self.videoDataOutput)
        } else {
            debugPrint("could not add video output")
        }
        self.videoDataOutput.connections.first?.videoOrientation = .portrait
        
        self.captureSession.commitConfiguration()
        self.captureSession.startRunning()

        // MARK: Setup preview layer
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        self.previewLayer.frame = self.view.frame
        self.previewLayer.videoGravity = .resizeAspectFill
        self.view.layer.insertSublayer(self.previewLayer, at: 0)
        self.previewLayer.frame = CGRect(origin: .zero, size: self.view.frame.size)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let videoQueue = DispatchQueue(label: "camera_frame_processing_queue", qos: .userInteractive)
        self.videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
        
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if captureSession.isRunning {
            captureSession.stopRunning()
            previewLayer = nil
            captureSession = nil
            clearTextBoxLayer()
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    // MARK: Implement delegate's image capture output
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            debugPrint("Unable to get image from sample buffer")
            return
        }
        
        self.detectText(buffer: frame)
    }

    // MARK: Setup text recognition request
    func detectText(buffer: CVPixelBuffer) {
        let request = VNRecognizeTextRequest(completionHandler: textRecognitionHandler)

        // Print default recognition languages
        // print(try? VNRecognizeTextRequest.supportedRecognitionLanguages(for: .fast, revision: VNRecognizeTextRequest.defaultRevision))

        request.recognitionLanguages = ["pt-BR", "en-US", "es-ES"]

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        performDetection(request: request, buffer: buffer)
    }
    

    // MARK: perform text detection
    func performDetection(request: VNRecognizeTextRequest, buffer: CVPixelBuffer) {
        let requests = [request]
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up, options: [:])

        // Perform the recognition in background thread. Otherwise, it ay block another thread
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform(requests)
            } catch let error {
                print("Error: \(error)")
            }
        }
    }

    // MARK: Setup text recognition handler
    private func textRecognitionHandler(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            // No result
            DispatchQueue.main.async {
                self.clearTextBoxLayer()
            }
            return
        }

        DispatchQueue.main.async {
            self.clearTextBoxLayer()
        }
        for result in observations {
            // Find the recognized text in the center of screen with certain confidence
            for text in result.topCandidates(1)
            where text.confidence >= 0.5 && result.boundingBox.contains(.init(x: 0.5, y: 0.5)) {
                // Update UI in main thread as the image is analyzed in background thread
                DispatchQueue.main.async {
                    let trimmedText = text.string.trimmingCharacters(in: .whitespacesAndNewlines)

                    self.delegate?.foundText(text: trimmedText)

                    self.highlightWord(box: result)
                }
                
                return // Use the first one only
            }
        }
    }

    // MARK: Create text recognition bounding box highlight layer
    private func highlightWord(box: VNRecognizedTextObservation) {
        recognizedTextBoxLayer?.removeFromSuperlayer()

        guard let candidate = box.topCandidates(1).first else { return }

        let stringRange = candidate.string.startIndex..<candidate.string.endIndex
        let boxObservation = try? candidate.boundingBox(for: stringRange)

        let boundingBox = boxObservation?.boundingBox ?? .zero
        
        let viewWidth = Int(view.frame.size.width)
        let viewHeight = Int(view.frame.size.height)

        // Normalize bounding box to view coordinate system
        let rect = VNImageRectForNormalizedRect(boundingBox, viewWidth, viewHeight)

        // Create the rectangle layer
        let outline = CALayer()
        outline.frame = rect
        outline.borderWidth = 1.0
        outline.borderColor = UIColor.red.cgColor
        recognizedTextBoxLayer = outline

        if let layer = previewLayer {
            // Insert the bounding box above the AVCaptureVideo preview layer
            layer.insertSublayer(outline, above: layer)
        } else {
            // Insert the bounding box to the bottom layer
            self.view.layer.insertSublayer(outline, at: 0)
        }
    }
    
    private func clearTextBoxLayer() {
        recognizedTextBoxLayer?.removeFromSuperlayer()
        recognizedTextBoxLayer = nil
    }
}

protocol TextFoundDelegate {    
    func foundText(text: String)
}
