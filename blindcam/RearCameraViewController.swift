//
//  ViewController.swift
//  Inception
//
//  Created by Mohammed Lazim on 7/6/17.
//  Copyright © 2017 iostreamh. All rights reserved.
//

import UIKit
import AVFoundation

class RearCameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var predictionText = ""
    @IBOutlet weak var resizedImage: UIImageView!
    
    let cameraSession = AVCaptureSession()
    var photoImage = UIImage()
    
    let alert = UIAlertController(
        title: "정확한 인식을 위해 대상에 카메라를 2에서 3초이상 대고 인식을 시켜주세요.",
        message: "",
        preferredStyle: .alert)
    
    let checkAction = UIAlertAction(
        title: "예",
        style: UIAlertActionStyle.cancel) {
            action in
            print("pressed Cancel Button")
    }
    
    
    let captureDevice = AVCaptureDevice.default(for: .video)! // todo: Can return nil. MDM restrictions
    
    lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let preview =  AVCaptureVideoPreviewLayer(session: self.cameraSession)
        preview.videoGravity = .resizeAspectFill
        return preview
    }()
    
    var model = blindcam()
    
    private let sessionQueue = DispatchQueue(label: "session queue", attributes: [], target: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        alert.addAction(checkAction)
        
        predictionText = "잠시 기다린 뒤에 인식해주세요."
        
        
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var frame = view.frame
        frame.size.height = frame.size.height - 76.0
        previewLayer.frame = frame
        
        view.layer.addSublayer(previewLayer)
        cameraSession.startRunning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection){
        
        connection.videoOrientation = .portrait
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let ciImage = CIImage(cvImageBuffer: imageBuffer)
            let img = UIImage(ciImage: ciImage).resizeTo(CGSize(width: 299, height: 299))
            self.photoImage = UIImage(ciImage: ciImage)
            if let uiImage = img {
                let pixelBuffer = uiImage.buffer()!
                let output = try? model.prediction(image: pixelBuffer)
                
                DispatchQueue.main.async {
                    
                    self.resizedImage.image = uiImage                           //ML PHOTO OUTPUT
                    self.predictionText = self.cutResultLabel(label: (output?.classLabel)!) //TEXT OUTPUT HERE
                    
                }
            }
        }
    }
    
    
    
    @IBAction func readItem(_ sender: UIButton) {
        let speechVoice = AVSpeechUtterance(string: predictionText)
        speechVoice.voice = AVSpeechSynthesisVoice(language: "en-US")
        let synth = AVSpeechSynthesizer()

        synth.speak(speechVoice)
    }
    
    func cutResultLabel(label: String)-> String{
        
        let seperated = label.components(separatedBy: ", ")
        var cuttedLabel = ""
        
        if seperated[0] != "" {
            cuttedLabel = seperated[0]
        }else{
            cuttedLabel = "인식에 실패했습니다"
        }
        
        return cuttedLabel
    }
    
    @IBAction func changeToFrontCam(_ sender: UIButton){
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "FrontCameraVC") as? FrontCameraViewController
        {
            present(vc, animated: true, completion: nil)
        }
    }
    
    @IBAction func showPhotos(_ sender: UIButton) {
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PhotoVC") as? PhotoViewController
        {
            present(vc, animated: true, completion: nil)
        }
    }
    
    
    @IBAction func savePhoto(_ sender: Any) {
        
    }
}

extension UIImage {
    func buffer() -> CVPixelBuffer? {
        return UIImage.buffer(from: self)
    }
    
    // Taken from:
    // https://stackoverflow.com/questions/44462087/how-to-convert-a-uiimage-to-a-cvpixelbuffer
    // https://www.hackingwithswift.com/whats-new-in-ios-11
    static func buffer(from image: UIImage) -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard (status == kCVReturnSuccess) else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.translateBy(x: 0, y: image.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context!)
        image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
    
    func resizeTo(_ size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContext(size)
        draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    
}


//https://www.invasivecode.com/weblog/AVFoundation-Swift-capture-video/
//https://gist.github.com/MihaelIsaev/273e4e8ddaaf062d2155
