//
//  SendViewController
//  PhotoDrop
//
//  Created by Pasin Suriyentrakorn on 11/16/14.
//  Copyright (c) 2014 Couchbase. All rights reserved.
//

import UIKit
import AssetsLibrary
import AVFoundation

class SendViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    @IBOutlet weak var previewView: UIView!

    @IBOutlet weak var statusLabel: UILabel!
    
    var previewLayer: AVCaptureVideoPreviewLayer!
    var session: AVCaptureSession!
    var replicator: CBLReplication!

    var sharedAssets:[ALAsset]?
    
    var database: CBLDatabase?

    override func viewDidLoad() {
        super.viewDidLoad()

        do {
            database = try DatabaseUtil.getEmptyDatabase("db")
        } catch let error as NSError {
            database = nil
            AppDelegate.showMessage("Cannot get a database with error : \(error.code)",
                title: "Error")
        }
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if database != nil && session == nil {
            startCaptureSession()
        }
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        if database != nil {
            do {
                try database!.deleteDatabase()
            } catch let error as NSError {
                NSLog("Cannot delete the database with error : ", error.description)
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Action

    @IBAction func cancelAction(sender: AnyObject) {
        self.navigationController?.dismissViewControllerAnimated(true,
            completion: { () -> Void in
                if self.replicator != nil {
                    self.replicator.stop()
                    NSNotificationCenter.defaultCenter().removeObserver(self,
                        name: kCBLReplicationChangeNotification, object: self.replicator)
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                }
        })
    }

    // MARK: - Capture QR Code

    func startCaptureSession() {
        let device = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        if device == nil {
            AppDelegate.showMessage("No video capture devices found", title: "")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            session = AVCaptureSession()
            session.addInput(input)
            
            let output = AVCaptureMetadataOutput()
            output.setMetadataObjectsDelegate(self, queue: dispatch_get_main_queue())
            session.addOutput(output)
            output.metadataObjectTypes = [AVMetadataObjectTypeQRCode]

            previewLayer = AVCaptureVideoPreviewLayer(session: session)
                as AVCaptureVideoPreviewLayer
            previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
            previewLayer.frame = self.previewView.bounds
            self.previewView.layer.addSublayer(previewLayer)

            session.startRunning()
        } catch {
            AppDelegate.showMessage("Cannot start QRCode capture session", title: "Error")
        }
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func captureOutput(captureOutput: AVCaptureOutput!,
        didOutputMetadataObjects metadataObjects: [AnyObject]!,
        fromConnection connection: AVCaptureConnection!) {
        if session == nil {
            // Workaround for iOS7 bugs
            return
        }

        for metadata in metadataObjects as! [AVMetadataObject] {
            if metadata.type == AVMetadataObjectTypeQRCode {
                let transformed = previewLayer.transformedMetadataObjectForMetadataObject(metadata)
                    as! AVMetadataMachineReadableCodeObject
                if let url = NSURL(string: transformed.stringValue) {
                    replicate(url)
                    session.stopRunning()
                    session = nil
                    break
                }
            }
        }
    }

    // MARK: - Replication

    func replicate(url: NSURL) {
        if database == nil {
            return
        }

        self.previewView.hidden = true;
        self.statusLabel.text = "Sending Photos ..."
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        
        var docIds: [String] = []
        for asset in sharedAssets! {
            let representation = asset.defaultRepresentation()
            let bufferSize = Int(representation.size())
            let buffer = UnsafeMutablePointer<UInt8>(malloc(bufferSize))
            let buffered = representation.getBytes(buffer, fromOffset: 0,
                length: Int(representation.size()), error: nil)
            let data = NSData(bytesNoCopy: buffer, length: buffered, freeWhenDone: true)

            let doc = database!.createDocument()
            let rev = doc.newRevision()
            rev.setAttachmentNamed("photo", withContentType: "application/octet-stream",
                content: data)
            do {
                try rev.save()
                docIds.append(doc.documentID)
            } catch let error as NSError {
                NSLog("Cannot save document: %@", error)
            }
        }

        if docIds.count > 0 {
            replicator = database!.createPushReplication(url)
            replicator.documentIDs = docIds

            NSNotificationCenter.defaultCenter().addObserverForName(kCBLReplicationChangeNotification,
                object: replicator, queue: nil) { (notification) -> Void in
                    if self.replicator.lastError == nil {
                        let totalCount = self.replicator.changesCount
                        let completedCount = self.replicator.completedChangesCount
                        if completedCount > 0 && completedCount == totalCount {
                            self.statusLabel.text = "Sending Completed"
                            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                        }
                    } else {
                        self.statusLabel.text = "Sending Abort"
                        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                    }
            }
            replicator.start()
        }
    }

}
