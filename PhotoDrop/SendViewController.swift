//
//  SendViewController.swift
//  PhotoDrop
//
//  Created by Pasin Suriyentrakorn.
//  Copyright © 2020 Pasin Suriyentrakorn. All rights reserved.
//

import UIKit
import AVFoundation
import Photos
import CouchbaseLiteSwift

class SendViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    @IBOutlet weak var previewView: UIView!

    @IBOutlet weak var statusLabel: UILabel!
    
    var assets: [PHAsset] = []
    
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    var session: AVCaptureSession!
    
    var replicator: Replicator!

    var database: Database!

    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            Database.log.console.level = .info
            database = try getEmptyDatabase()
        } catch let error as NSError {
            AppDelegate.showMessage("Cannot get a database with error : \(error.code)", title: "Error", on: self)
            self.navigationController?.dismiss(animated: true, completion: {})
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if session == nil {
            startCaptureSession()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Action

    @IBAction func cancelAction(_ sender: AnyObject) {
        self.navigationController?.dismiss(animated: true, completion: {
            self.deleteDatabase()
        })
    }

    // MARK: - Capture QR Code

    func startCaptureSession() {
        let device = AVCaptureDevice.default(for: .video)
        if device == nil {
            AppDelegate.showMessage("No video capture devices found", title: "", on: self)
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device!)
            session = AVCaptureSession()
            session.addInput(input)
            
            let output = AVCaptureMetadataOutput()
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            session.addOutput(output)
            output.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]

            previewLayer = AVCaptureVideoPreviewLayer(session: session)
                as AVCaptureVideoPreviewLayer
            previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
            previewLayer.frame = self.previewView.bounds
            self.previewView.layer.addSublayer(previewLayer)

            session.startRunning()
        } catch {
            AppDelegate.showMessage("Cannot start QRCode capture session", title: "Error", on: self)
        }
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        for metadata in metadataObjects {
            if metadata.type == AVMetadataObject.ObjectType.qr {
                let transformed = previewLayer.transformedMetadataObject(for: metadata)
                    as! AVMetadataMachineReadableCodeObject
                if let url = URL(string: transformed.stringValue!) {
                    sendPhotos(to: url)
                    session.stopRunning()
                    session = nil
                    break
                }
            }
        }
    }
    
    // MARK: - Database
    
    func getEmptyDatabase() throws -> Database {
        var db = try Database.init(name: "db")
        if (db.count > 0) {
            try db.delete()
            db = try Database.init(name: "db")
        }
        return db
    }

    func deleteDatabase() {
        do {
            try database.delete()
        } catch let error as NSError {
            NSLog("Cannot delete the database with error : ", error.description)
        }
    }
    
    // MARK: - Replicator

    func sendPhotos(to url: URL) {
        self.previewView.isHidden = true;
        self.statusLabel.text = "Preparing Photos ..."
        
        var docIDs: [String] = []
        for asset in assets {
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: nil) { (data, dataUTI, orientation, info) in
                let doc = MutableDocument()
                doc.setBlob(Blob.init(contentType: "application/octet-stream", data: data!), forKey: "photo")
                try! self.database.saveDocument(doc)
                docIDs.append(doc.id)
                
                if (docIDs.count == self.assets.count) {
                    self.replicate(documents: docIDs, to: url)
                }
            }
        }
    }
    
    func replicate(documents: [String], to url: URL) {
        let target = URLEndpoint.init(url: url)
        let config = ReplicatorConfiguration.init(database: database, target: target)
        config.replicatorType = .push
        config.documentIDs = documents
        
        let replicator = Replicator.init(config: config)
        replicator.addChangeListener { (change) in
            if change.status.activity == .stopped {
                if change.status.error == nil && change.status.progress.completed == change.status.progress.total {
                    self.statusLabel.text = "Sending Completed"
                } else {
                    self.statusLabel.text = "Sending Not Completed"
                }
            }
        }
        self.statusLabel.text = "Sending Photos ..."
        replicator.start()
    }

}
