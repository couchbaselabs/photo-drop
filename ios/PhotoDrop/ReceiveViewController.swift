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

    let kRequiresAuthentication:Bool = false

    @IBOutlet weak var imageView: UIImageView!

    @IBOutlet weak var statusLabel: UILabel!

    @IBOutlet weak var collectionView: UICollectionView!

    var listener: CBLListener!

    var library: ALAssetsLibrary!

    var assets:[ALAsset] = []
    
    var database: CBLDatabase!

    var syncUrl: NSURL!

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
        
        if (!startListener()) {
            AppDelegate.showMessage("Cannot start listener", title: "Error")
            return;
        }

        if syncUrl != nil {
            imageView.image = UIImage.qrCodeImageForString(syncUrl.absoluteString,
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

    func startListener() -> Bool {
        if listener != nil {
            return true
        }

        var error: NSError?
        listener = CBLListener(manager: CBLManager.sharedInstance(), port: 0)

        var username: String?
        var password: String?

        listener.requiresAuth = kRequiresAuthentication
        if listener.requiresAuth {
            username = secureGenerateKey(NSCharacterSet.URLUserAllowedCharacterSet())
            password = secureGenerateKey(NSCharacterSet.URLPasswordAllowedCharacterSet())
            listener.setPasswords([username! : password!])
        }

        var success = listener.start(&error)
        if success {
            syncUrl = generateSyncUrl(listener.URL, username: username, password: password,
                db: database.name)
            startObserveDatabaseChange()
            return true
        } else {
            listener = nil
            return false
        }
    }

    func stopListener() {
        if listener != nil {
            listener.stop()
            listener = nil
            stopObserveDatabaseChange()
        }
    }

    func secureGenerateKey(allowedCharacters: NSCharacterSet) -> String {
        let data = NSMutableData(length:32)!
        SecRandomCopyBytes(kSecRandomDefault, 32, UnsafeMutablePointer<UInt8>(data.mutableBytes))
        let key = data.base64EncodedStringWithOptions(
            NSDataBase64EncodingOptions.Encoding64CharacterLineLength)
        return key.stringByAddingPercentEncodingWithAllowedCharacters(allowedCharacters)!
    }

    func generateSyncUrl(base: NSURL, username: String?, password: String?, db: String) -> NSURL? {
        if let url = NSURL(string: db, relativeToURL: base) {
            if let urlComp = NSURLComponents(string: url.absoluteString!) {
                urlComp.user = username
                urlComp.password = password
                return urlComp.URL
            }
        }
        return nil
    }

    // MARK: - ALAssetsLibrary

    func assetsLibrary() -> ALAssetsLibrary {
        if library == nil {
            library = ALAssetsLibrary()
        }
        return library
    }

    func saveImageFromDocument(docId: String) {
        if let doc = database.existingDocumentWithID(docId) {
            if let attachment = doc.currentRevision?.attachmentNamed("photo") {
                if let image = UIImage(data: attachment.content!)?.CGImage {
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
                forIndexPath: indexPath) as! PhotoViewCell
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
