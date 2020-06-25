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
    
    var database: CBLDatabase?

    var syncUrl: URL!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.isHidden = true;

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

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        stopListener()
        
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
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) { }

    // MARK: - Action

    @IBAction func cancelAction(_ sender: AnyObject) {
        self.navigationController?.dismiss(animated: true,
            completion: { () -> Void in })
    }

    // MARK: - Listener

    func startListener() -> Bool {
        if listener != nil {
            return true
        }

        if database == nil {
            return false
        }

        listener = CBLListener(manager: CBLManager.sharedInstance(), port: 0)

        var username: String?
        var password: String?

        listener.requiresAuth = kRequiresAuthentication
        if listener.requiresAuth {
            username = secureGenerateKey(CharacterSet.urlUserAllowed) 
            password = secureGenerateKey(CharacterSet.urlPasswordAllowed)
            if username == nil || password == nil {
                return false
            }
            listener.setPasswords([username! : password!])
        }

        var success: Bool
        do {
            try listener.start()
            success = true
        } catch {
            success = false
        }
 
        guard let url =  listener.url else {
            listener = nil

            return false
        }

        if success {
            syncUrl = generateSyncUrl(url, username: username, password: password,
                db: database!.name)
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

    func secureGenerateKey(_ allowedCharacters: CharacterSet) -> String? {
        var bytes = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if result == errSecSuccess {
            let data = Data(bytes: bytes)
            let key = data.base64EncodedString(
                options: NSData.Base64EncodingOptions.lineLength64Characters)
            return key.addingPercentEncoding(withAllowedCharacters: allowedCharacters)!
        } else {
            return nil
        }
    }

    func generateSyncUrl(_ base: URL, username: String?, password: String?, db: String) -> URL? {
        if let url = URL(string: db, relativeTo: base) {
            if var urlComp = URLComponents(string: url.absoluteString) {
                urlComp.user = username
                urlComp.password = password
                return urlComp.url
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

    func saveImageFromDocument(_ docId: String) {
        if database == nil {
            return
        }

        if let doc = database!.existingDocument(withID: docId) {
            if let attachment = doc.currentRevision?.attachmentNamed("photo") {
                let library = assetsLibrary()
                library.writeImageData(toSavedPhotosAlbum: attachment.content!, metadata: nil, completionBlock: { (url, error) in
                    if url != nil {
                        
                        library.asset(for: url, resultBlock: { (asset) in
                            if asset != nil {
                                self.assets.insert(asset!, at: 0)
                            }
                            DispatchQueue.main.async(execute: {
                                self.collectionView.insertItems(
                                    at:[IndexPath(row: 0, section: 0) ] )
                            })
                        }, failureBlock: { (error) in
                            
                        })
                        
                       
                    }
                })
            }
        }
    }

    // MARK: - Database Change

    func startObserveDatabaseChange() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name.cblDatabaseChange,
            object: database, queue: nil) {
                (notification) -> Void in
                if let changes = notification.userInfo!["changes"] as? [CBLDatabaseChange] {
                    for change in changes {
                        DispatchQueue.main.async(execute: {
                            if self.collectionView.isHidden {
                                self.collectionView.isHidden = false
                            }
                            self.saveImageFromDocument(change.documentID)
                        })
                    }
                }
        }
    }

    func stopObserveDatabaseChange() {
        NotificationCenter.default.removeObserver(self,
            name: NSNotification.Name.cblDatabaseChange, object: database)
    }

    // MARK: - UICollectionView

    func collectionView(_ collectionView: UICollectionView,
        numberOfItemsInSection section: Int) -> Int {
            return self.assets.count
    }

    func collectionView(_ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell",
                for: indexPath) as! PhotoViewCell
            let asset = assets[indexPath.row]
            cell.imageView.image = UIImage(cgImage: asset.thumbnail().takeUnretainedValue())
            return cell
    }

    func collectionView(_ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize {
            let width = collectionView.bounds.size.width
            let size = (width - 6) / 3.0
            return CGSize(width: size, height: size)
    }

    func collectionView(_ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat {
            return 3.0
    }
}
