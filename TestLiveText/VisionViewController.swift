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
        captureSession = AVCaptureSession()
        captureSession.beginConfiguration()
        
//        captureSession.sessionPreset = .medium
        
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            //handle this appropriately for production purposes
            fatalError("no back camera")
        }

        guard let backInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            fatalError("could not create input device from back camera")
        }

        guard captureSession.canAddInput(backInput) else {
            fatalError("could not add back camera input to capture session")
        }
        
        captureSession.addInput(backInput)
        
        // MARK: Setup video output
        self.videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
//        self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
        let videoQueue = DispatchQueue(label: "camera_frame_processing_queue", qos: .userInteractive)
        self.videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)

        if captureSession.canAddOutput(self.videoDataOutput) == true {
            self.captureSession.addOutput(self.videoDataOutput)
        } else {
            debugPrint("could not add video output")
        }
        self.videoDataOutput.connections.first?.videoOrientation = .portrait
        
        // MARK: Setup preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = self.view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
        previewLayer.frame = CGRect(origin: .zero, size: view.frame.size)
        
        captureSession.commitConfiguration()
        captureSession.startRunning()
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
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            debugPrint("Unable to get image from sample buffer")
            return
        }
        
        self.detectText(buffer: frame)
    }
    
    func detectText(buffer: CVPixelBuffer) {
        let request = VNRecognizeTextRequest(completionHandler: textRecognitionHandler)

        // try? VNRecognizeTextRequest.supportedRecognitionLanguages(for: .fast, revision: VNRecognizeTextRequest.defaultRevision)

        request.recognitionLanguages = ["pt-BR", "en-US", "es-ES"]

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        performDetection(request: request, buffer: buffer)
    }
    

    // MARK: perform detection
    func performDetection(request: VNRecognizeTextRequest, buffer: CVPixelBuffer) {
        let requests = [request]
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up, options: [:])

        // perform the recognition in background thread. Otherwise, it ay block another thread
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform(requests)
            } catch let error {
                print("Error: \(error)")
            }
        }
    }
    
    private func textRecognitionHandler(request: VNRequest, error: Error?) {
        guard let observations = request.results else {
            // no result
            DispatchQueue.main.async {
                self.clearTextBoxLayer()
            }
            return
        }
        
        let results = observations.compactMap { $0 as? VNRecognizedTextObservation }
        DispatchQueue.main.async {
            self.clearTextBoxLayer()
        }
        for result in results {
            // find the recognized text in the center of image with certain confidence
            for text in result.topCandidates(1)
            where text.confidence >= 0.5 && result.boundingBox.contains(.init(x: 0.5, y: 0.5)) {
                // Update UI in main thread as the image is analyzed in background thread
                DispatchQueue.main.async {
                    let trimmedText = text.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    print(text.string)
                    self.delegate?.textWasFound(result: true)
                    self.delegate?.foundText(result: trimmedText)
                    self.highlightWord(box: result)
                }
                
                return // use the first one only
            }
        }
    }

    private func highlightWord(box: VNRecognizedTextObservation) {
        recognizedTextBoxLayer?.removeFromSuperlayer()

        // the bounding box is originated from bottom left corner with normalized value (0-1)
        // so we need to convert it to the view coordinate system
        let xCord = box.topLeft.x * self.view.frame.size.width
        let yCord = ((1 - box.topLeft.y) * self.view.frame.size.height) + 50
        let width = (box.topRight.x - box.topLeft.x) * self.view.frame.size.width
        let height = (box.topLeft.y - box.bottomLeft.y) * self.view.frame.size.height

        let outline = CALayer()
        outline.frame = CGRect(x: xCord, y: yCord, width: width, height: height)
        outline.borderWidth = 1.0
        outline.borderColor = UIColor.red.cgColor
        recognizedTextBoxLayer = outline

        if let layer = previewLayer {
            // insert the bounding box above the AVCaptureVideo preview layer
            layer.insertSublayer(outline, above: layer)
        } else {
            // insert the bounding box to the bottom layer
            self.view.layer.insertSublayer(outline, at: 0)
        }
    }
    
    private func clearTextBoxLayer() {
        recognizedTextBoxLayer?.removeFromSuperlayer()
        recognizedTextBoxLayer = nil
    }
}

protocol TextFoundDelegate {
    func textWasFound(result: Bool)
    
    func foundText(result: String)
}
