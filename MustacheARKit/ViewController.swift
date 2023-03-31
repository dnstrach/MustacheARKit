//
//  ViewController.swift
//  MustacheARKit
//
//  Created by Dominique Strachan on 3/28/23.
//

import UIKit
import ARKit
import ARVideoKit
import Photos

class ViewController: UIViewController {
    
    
    //MARK: - Properties
    let mustacheOptions = ["mustache1", "mustache2", "mustache3", "mustache4"]
    let features = ["mustache"]
    let featureIndices = [[2]]
    
    let recordingQueue = DispatchQueue(label: "recordingThread", attributes: .concurrent)
    var recorder: RecordAR?
    
    //MARK: - Outlets
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var recordButton: UIButton!
    
    
    //MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        recorder = RecordAR(ARSceneKit: sceneView)
        
        // Set the recorder's delegate
        recorder?.delegate = self

        // Set the renderer's delegate
        recorder?.renderAR = self
        
        // Configure the renderer to perform additional image & video processing 👁
        recorder?.onlyRenderWhileRecording = false
        
        // Configure ARKit content mode. Default is .auto
        recorder?.contentMode = .aspectFill
        
        //record or photo add environment light rendering, Default is false
        recorder?.enableAdjustEnvironmentLighting = true
        
        // Set the UIViewController orientations
        recorder?.inputViewOrientations = [.landscapeLeft, .landscapeRight, .portrait]
        // Configure RecordAR to store media files in local app directory
        recorder?.deleteCacheWhenExported = false
        
        recordButtonStyle()

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARFaceTrackingConfiguration()
        sceneView.session.run(configuration)
        recorder?.prepare(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
        
        if recorder?.status == .recording {
            recorder?.stopAndExport()
        }
        recorder?.onlyRenderWhileRecording = true
        recorder?.prepare(ARFaceTrackingConfiguration())
        
        recorder?.rest()
        
    }
    
    // MARK: - Exported UIAlert present method
    func exportMessage(success: Bool, status: PHAuthorizationStatus) {
        if success {
            let alert = UIAlertController(title: "Saved", message: "Video successfully saved to Photos!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Yay", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }else if status == .denied || status == .restricted || status == .notDetermined {
            let errorAlert = UIAlertController(title: "Enable Access", message: "Please allow access to the photo library to save video.", preferredStyle: .alert)
            errorAlert.addAction(UIAlertAction(title: "Later", style: UIAlertAction.Style.default, handler: nil ))
            self.present(errorAlert, animated: true, completion: nil)
        }
    }

    //MARK: - Actions
    @IBAction func viewTapped(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: sceneView)
        let results = sceneView.hitTest(location, options: nil)
        if let result = results.first,
           let node = result.node as? FaceNode {
            node.next()
        }
    }
    
    @IBAction func startRecording(_ sender: UIButton) {
        
        if sender.tag == 0 {
            //Record
            if recorder?.status == .readyToRecord {
                recordButton.layer.borderColor = UIColor.red.cgColor
                recordingQueue.async {
                    self.recorder?.record()
                }
            } else if recorder?.status == .recording {
                recordButton.layer.borderColor = UIColor.white.cgColor
                recorder?.stop() { path in
                    self.recorder?.export(video: path) { saved, status in
                        DispatchQueue.main.sync {
                            self.exportMessage(success: saved, status: status)
                        }
                    }
                }
            }
        }
    }
    //MARK: - Helpers
    func updateFeatures(for node: SCNNode, using anchor: ARFaceAnchor) {
        for (feature, indices) in zip(features, featureIndices) {
            let child = node.childNode(withName: feature, recursively: false) as? FaceNode
            let vertices = indices.map { anchor.geometry.vertices[$0] }
            child?.updatePosition(for: vertices)
        }
    }
    
    func recordButtonStyle() {
        recordButton.frame = CGRect(x: 0, y: 0, width: 75, height: 75)
        recordButton.center = CGPoint(x: view.frame.size.width/2, y: view.frame.size.height - 100)
        recordButton.layer.cornerRadius = 37.5
        recordButton.layer.borderWidth = 5
        recordButton.layer.borderColor = UIColor.white.cgColor
    }
    
}//end of class

//MARK: - ARKit Delegate
extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        
        let device: MTLDevice!
        device = MTLCreateSystemDefaultDevice()
        guard let faceAnchor = anchor as? ARFaceAnchor else {
            return nil
        }
        let faceGeometry = ARSCNFaceGeometry(device: device)
        let node = SCNNode(geometry: faceGeometry)
        node.geometry?.firstMaterial?.fillMode = .lines
        node.geometry?.firstMaterial?.transparency = 0.0
        
        let mustacheNode = FaceNode(with: mustacheOptions)
        mustacheNode.name = "mustache"
        node.addChildNode(mustacheNode)
        
        updateFeatures(for: node, using: faceAnchor)
        
        return node
    }
    
    func renderer(
        _ renderer: SCNSceneRenderer,
        didUpdate node: SCNNode,
        for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor,
                  let faceGeometry = node.geometry as? ARSCNFaceGeometry else {
                return
            }
            
            faceGeometry.update(from: faceAnchor.geometry)
            updateFeatures(for: node, using: faceAnchor)
        }
} //end of extension

//MARK: - ARVideoKit Delegate Methods
extension ViewController: RecordARDelegate, RenderARDelegate {
    func frame(didRender buffer: CVPixelBuffer, with time: CMTime, using rawBuffer: CVPixelBuffer) {
        
    }
    
    func recorder(didEndRecording path: URL, with noError: Bool) {
        
    }
    
    func recorder(didFailRecording error: Error?, and status: String) {
        
    }
    
    func recorder(willEnterBackground status: ARVideoKit.RecordARStatus) {

    }
}


