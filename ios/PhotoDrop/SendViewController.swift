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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if database != nil && session == nil {
            startCaptureSession()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if database != nil {
            do {
                try database!.delete()
            } catch let error as NSError {
                NSLog("Cannot delete the database with error : ", error.description)
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Action

    @IBAction func cancelAction(_ sender: AnyObject) {
        self.navigationController?.dismiss(animated: true,
            completion: { () -> Void in
                if self.replicator != nil {
                    self.replicator.stop()
                    NotificationCenter.default.removeObserver(self,
                        name: NSNotification.Name.cblReplicationChange, object: self.replicator)
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                }
        })
    }

    // MARK: - Capture QR Code

    func startCaptureSession() {
        let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        if device == nil {
            AppDelegate.showMessage("No video capture devices found", title: "")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            session = AVCaptureSession()
            session.addInput(input)
            
            let output = AVCaptureMetadataOutput()
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
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

    func captureOutput(_ captureOutput: AVCaptureOutput!,
        didOutputMetadataObjects metadataObjects: [Any]!,
        from connection: AVCaptureConnection!) {
        if session == nil {
            // Workaround for iOS7 bugs
            return
        }

        for metadata in metadataObjects as! [AVMetadataObject] {
            if metadata.type == AVMetadataObjectTypeQRCode {
                let transformed = previewLayer.transformedMetadataObject(for: metadata)
                    as! AVMetadataMachineReadableCodeObject
                if let url = URL(string: transformed.stringValue) {
                    replicate(url)
                    session.stopRunning()
                    session = nil
                    break
                }
            }
        }
    }

    // MARK: - Replication

    func replicate(_ url: URL) {
        if database == nil {
            return
        }

        self.previewView.isHidden = true;
        self.statusLabel.text = "Sending Photos ..."
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        var docIds: [String] = []
        for asset in sharedAssets! {
            let representation = asset.defaultRepresentation()
            let bufferSize = Int(representation?.size() ?? 0)
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity:bufferSize)
            let buffered = representation?.getBytes(buffer, fromOffset: 0,
                length: Int(representation?.size() ?? 0), error: nil) ?? 0
            let data = Data(bytesNoCopy: UnsafeMutablePointer<UInt8>(buffer), count: buffered, deallocator: .free)

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

            NotificationCenter.default.addObserver(forName: NSNotification.Name.cblReplicationChange,
                object: replicator, queue: nil) { (notification) -> Void in
                    if self.replicator.lastError == nil {
                        let totalCount = self.replicator.changesCount
                        let completedCount = self.replicator.completedChangesCount
                        if completedCount > 0 && completedCount == totalCount {
                            self.statusLabel.text = "Sending Completed"
                            UIApplication.shared.isNetworkActivityIndicatorVisible = false
                        }
                    } else {
                        self.statusLabel.text = "Sending Abort"
                        UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    }
            }
            replicator.start()
        }
    }

}
