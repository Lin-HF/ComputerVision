//
//  ViewController.swift
//  HandGestureRecognition
//
//  Created by Haifeng Lin on 04/02/18.
//  Copyright © 2018 Haifeng Lin. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision
import AVFoundation

class ViewController: UIViewController, ARSCNViewDelegate {
    //Set for music play app
    var audioPlayer: AVAudioPlayer!
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var debugTextView: UITextView!
    @IBOutlet weak var textOverlay: UITextField!
    @IBOutlet weak var displayLbl: UILabel!
    
    let dispatchQueue = DispatchQueue(label: "dispatchqueueml")
    var visionRequests = [VNRequest]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let url = Bundle.main.url(forResource: "music", withExtension: "mp3")
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url!)
            audioPlayer.prepareToPlay()
            audioPlayer.currentTime = 0
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: {(timer) in
                self.displayLbl.text = "Music Play time:\(round(self.audioPlayer.currentTime*10)/10)"
            })
            displayLbl.text = " Music Play time:\(audioPlayer.currentTime)"
        } catch let error as NSError {
            print("\(error.debugDescription)")
        }

        // Set the view's delegate
        sceneView.delegate = self
        // fps and timing information
        sceneView.showsStatistics = true
        //
        let scene = SCNScene()
        // Set the scene to the view
        sceneView.scene = scene
        
        //Start Core ML
        // Setup Vision Model
        guard let myModel = try? VNCoreMLModel(for: gesture01().model) else {
            fatalError("Can't load model.")
        }
        
        // Set up ml Request
        let classificationRequest = VNCoreMLRequest(model: myModel, completionHandler: classificationCompleteHandler)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop //scale to appropriate size.
        visionRequests = [classificationRequest]
        
        loopUpdate()
    }
    func classificationCompleteHandler(request: VNRequest, error: Error?) {
        // Deal with errors
        if error != nil {
            print("Error: " + (error?.localizedDescription)!)
            return
        }
        guard let observations = request.results else {
            print("No results")
            return
        }
        
        // Get Classifications
        let classifications = observations[0...2] // top 3 results
            .compactMap({ $0 as? VNClassificationObservation })
            .map({ "\($0.identifier) \(String(format:" : %.2f", $0.confidence))" })
            .joined(separator: "\n")
        
        // Render Classifications
        DispatchQueue.main.async {
            // Classifications
            
            // Display predictions on screen
            self.debugTextView.text = "TOP 3 Predictions: \n" + classifications
            // Display prediction Symbols
            var symbol = "❓" //When no results
            let topPrediction = classifications.components(separatedBy: "\n")[0]
            let topPredictionName = topPrediction.components(separatedBy: ":")[0].trimmingCharacters(in: .whitespaces)
            // Only display a prediction if confidence is more than 1%
            let topPredictionScore:Float? = Float(topPrediction.components(separatedBy: ":")[1].trimmingCharacters(in: .whitespaces))
            if (topPredictionScore != nil && topPredictionScore! > 0.01) {
                switch topPredictionName {
                case "fist-hand":
                    symbol = "👊"
                    break
                case "five-hand":
                    symbol = "🖐"
                    break
                case "checkmark-hand":
                    symbol = "✅"
                    break
                default:
                    symbol = "❓"
                }
            }
            
            self.textOverlay.text = symbol
            switch symbol {
            case "🖐":
                self.audioPlayer.pause()
                break
            case "👊":
                self.audioPlayer.play()
                break
            case "✅":
                self.audioPlayer.stop()
                self.audioPlayer.currentTime = 0
                break
            default:
                break
            }
            
        }
    }
    
    //Code Inference:  from Hunter Ward form(https://medium.com/@hunter.ley.ward/create-your-own-object-recognizer-ml-on-ios-7f8c09b461a1)
    // Run continuously
    func loopUpdate() {
        dispatchQueue.async {
            self.updateCoreML()//Update.
            self.loopUpdate() //Loop
        }
    }
    
    func updateCoreML() {
        // Get Camera Image
        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        let ciImage = CIImage(cvPixelBuffer: pixbuff!)
        // Set request
        let imageRequestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        //
        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print(error)
        }
    }
    //Code Inference End
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

}
