//
//  FrontCameraViewController.swift
//  blindcam
//
//  Created by 이씨안 on 2017. 10. 15..
//  Copyright © 2017년 iostreamh. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class FrontCameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    let cameraSession = AVCaptureSession()
    var isFaceVisible = false
    var queue = 0
    
    lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let preview =  AVCaptureVideoPreviewLayer(session: self.cameraSession)
        preview.videoGravity = .resizeAspectFill
        return preview
    }()
    
    var model = blindcam()
    
    private let sessionQueue = DispatchQueue(label: "session queue", attributes: [], target: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)!
        
        do {
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            
            cameraSession.beginConfiguration()
            
            if (cameraSession.canAddInput(deviceInput) == true) {
                cameraSession.addInput(deviceInput)
            }
            
            let dataOutput = AVCaptureVideoDataOutput()
            
            dataOutput.videoSettings = [((kCVPixelBufferPixelFormatTypeKey as NSString) as String) : NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as UInt32)]
            
            dataOutput.alwaysDiscardsLateVideoFrames = true
            
            if (cameraSession.canAddOutput(dataOutput) == true) {
                cameraSession.addOutput(dataOutput)
            }
            
            cameraSession.commitConfiguration()
            
            let queue = DispatchQueue(label: "com.iostreamh.inception.video-output")
            dataOutput.setSampleBufferDelegate(self, queue: queue)
            
        }
        catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
        
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection){
        
        
        connection.videoOrientation = .portrait
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let ciImage = CIImage(cvImageBuffer: imageBuffer)
            let img = UIImage(ciImage: ciImage).resizeTo(CGSize(width: 299, height: 299))
            if let uiImage = img {
                let pixelBuffer = uiImage.buffer()!
                let request = VNDetectFaceRectanglesRequest { (req, err) in
                    
                    if let err = err {
                        print("failed to detect faces:", err)
                        return
                    }
                    
                    print(req)
                    if self.queue > 0{
                        self.queue -= 1
                    }
                    
                    if self.queue == 0 && self.isFaceVisible == true{
                        print("NO MORE FACE RECOGNIZED")
                        self.isFaceVisible = false
                        self.readFaceVisibility(method: self.isFaceVisible)
                    }
                    
                    req.results?.forEach({ (res) in
                        print(res)
                        
                        print("SUCCEED!")
                        self.queue = 5
                        if self.isFaceVisible == false{
                            self.isFaceVisible = true
                            self.readFaceVisibility(method: self.isFaceVisible)
                        }
                        guard let faceObservation = res as? VNFaceObservation else { return }
                        
                        print(faceObservation.boundingBox)
                    })
                }
                
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [ : ] )
                
                
                do{
                    try handler.perform([request])
                } catch let reqErr {
                    print("FAILED : ",reqErr)
                }
                
                DispatchQueue.main.async {
                    
                    
                }
            }
        }
    }
    
    
    @IBAction func showPhoto(_ sender: Any) {
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PhotoVC") as? PhotoViewController
        {
            present(vc, animated: true, completion: nil)
        }
    }
    
    func readFaceVisibility(method:Bool){
        var sayingText = ""
        
        if method == false{
            sayingText = "얼굴이 인식되지 않습니다."
        }else{
            sayingText = "얼굴이 인식되었습니다."
        }
        
        let speechVoice = AVSpeechUtterance(string: sayingText)
        speechVoice.voice = AVSpeechSynthesisVoice(language: "ko-KR")
        let synth = AVSpeechSynthesizer()
        
        synth.speak(speechVoice)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var frame = view.frame
        frame.size.height = frame.size.height - 76.0
        previewLayer.frame = frame
        
        view.layer.addSublayer(previewLayer)
        cameraSession.startRunning()
    }
    
    @IBAction func changeToRearCamera(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
