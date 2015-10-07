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

    func getIFAddresses() -> [String] {
        var addresses = [String]()

        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs> = nil
        if getifaddrs(&ifaddr) == 0 {

            // For each interface ...
            for (var ptr = ifaddr; ptr != nil; ptr = ptr.memory.ifa_next) {
                let flags = Int32(ptr.memory.ifa_flags)
                var addr = ptr.memory.ifa_addr.memory

                // Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
                if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                    if addr.sa_family == UInt8(AF_INET) || addr.sa_family == UInt8(AF_INET6) {

                        // Convert interface address to a human readable string:
                        var hostname = [CChar](count: Int(NI_MAXHOST), repeatedValue: 0)
                        if (getnameinfo(&addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count),
                            nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                                if let address = String.fromCString(hostname) {
                                    addresses.append(address)
                                }
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }

        return addresses
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

                urlComp.host = getIFAddresses()[0]

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
