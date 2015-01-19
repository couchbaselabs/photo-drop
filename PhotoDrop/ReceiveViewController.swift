//
//  ReceiveViewController.swift
//  PhotoDrop
//
//  Created by Pasin Suriyentrakorn on 11/22/14.
//  Copyright (c) 2014 Couchbase. All rights reserved.
//

import UIKit
import AssetsLibrary

class ReceiveViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    @IBOutlet weak var imageView: UIImageView!

    @IBOutlet weak var statusLabel: UILabel!

    @IBOutlet weak var collectionView: UICollectionView!

    var listener: CBLListener!

    var library: ALAssetsLibrary!

    var assets:[ALAsset] = []
    
    var database: CBLDatabase!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.hidden = true;
        
        var error: NSError?
        database = DatabaseUtil.getEmptyDatabase("db", error: &error)
        if error != nil {
            AppDelegate.showMessage("Cannot get a database with error : \(error!.code)", title: "Error")
        }
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if database == nil {
            return;
        }
        
        startListener()

        if let url = syncUrl()?.absoluteString {
            imageView.image = UIImage.qrCodeImageForString(url,
                size: imageView.frame.size)
        }
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        stopListener()
        
        if database != nil {
            var error: NSError?
            if !database.deleteDatabase(&error) {
                NSLog("Cannot delete the database with error : ", error!.description)
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) { }

    // MARK: - Action

    @IBAction func cancelAction(sender: AnyObject) {
        self.navigationController?.dismissViewControllerAnimated(true,
            completion: { () -> Void in })
    }

    // MARK: - Listener

    func startListener() {
        if listener != nil {
            return
        }

        var error: NSError?
        listener = CBLListener(manager: CBLManager.sharedInstance(), port: 0)
        var success = listener.start(&error)
        if success {
            startObserveDatabaseChange()
        } else {
            listener = nil
            AppDelegate.showMessage("Cannot start listener", title: "Error")
        }
    }

    func stopListener() {
        if listener != nil {
            listener.stop()
            listener = nil
            stopObserveDatabaseChange()
        }
    }

    func syncUrl() -> NSURL? {
        if listener != nil {
            return NSURL(string: database.name, relativeToURL: listener.URL)
        }
        return nil
    }

    func assetsLibrary() -> ALAssetsLibrary {
        if library == nil {
            library = ALAssetsLibrary()
        }
        return library
    }

    func saveImageFromDocument(docId: String) {
        let app = UIApplication.sharedApplication().delegate as AppDelegate
        if let doc = database.existingDocumentWithID(docId) {
            if doc.currentRevision.attachments.count > 0 {
                let attachment = doc.currentRevision.attachments[0] as CBLAttachment
                if let image = UIImage(data: attachment.content)?.CGImage {
                    let library = assetsLibrary()
                    library.writeImageDataToSavedPhotosAlbum(attachment.content, metadata: nil,
                        completionBlock: { (url: NSURL!, error: NSError!) -> Void in
                        if url != nil {
                            library.assetForURL(url, resultBlock:
                                {(asset: ALAsset!) -> Void in
                                    self.assets.insert(asset, atIndex: 0)
                                    dispatch_async(dispatch_get_main_queue(), {
                                        self.collectionView.insertItemsAtIndexPaths(
                                            [NSIndexPath(forRow: 0, inSection: 0)])
                                    })
                                })
                                {(error: NSError!) -> Void in
                            }
                        }
                    })
                }
            }
        }
    }

    // MARK: - Database Change

    func startObserveDatabaseChange() {
        NSNotificationCenter.defaultCenter().addObserverForName(kCBLDatabaseChangeNotification,
            object: database, queue: nil) {
                (notification) -> Void in
                if let changes = notification.userInfo!["changes"] as? [CBLDatabaseChange] {
                    for change in changes {
                        dispatch_async(dispatch_get_main_queue(), {
                            if self.collectionView.hidden {
                                self.collectionView.hidden = false
                            }
                            self.saveImageFromDocument(change.documentID)
                        })
                    }
                }
        }
    }

    func stopObserveDatabaseChange() {
        NSNotificationCenter.defaultCenter().removeObserver(self,
            name: kCBLDatabaseChangeNotification, object: database)
    }

    // MARK: - UICollectionView

    func collectionView(collectionView: UICollectionView,
        numberOfItemsInSection section: Int) -> Int {
            return self.assets.count
    }

    func collectionView(collectionView: UICollectionView,
        cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier("photoCell",
                forIndexPath: indexPath) as PhotoViewCell
            let asset = assets[indexPath.row]
            cell.imageView.image = UIImage(CGImage: asset.thumbnail().takeUnretainedValue())
            return cell
    }


    func collectionView(collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
            let width = collectionView.bounds.size.width
            let size = (width - 6) / 3.0
            return CGSizeMake(size, size)
    }

    func collectionView(collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat {
            return 3.0
    }
}
