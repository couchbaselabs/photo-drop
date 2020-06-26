//
//  ReceiveViewController.swift
//  PhotoDrop
//
//  Created by Pasin Suriyentrakorn.
//  Copyright © 2020 Pasin Suriyentrakorn. All rights reserved.
//

import UIKit
import Photos
import CouchbaseLiteSwift

class ReceiveViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!

    @IBOutlet weak var statusLabel: UILabel!

    @IBOutlet weak var collectionView: UICollectionView!
    
    var thumbnailSize: CGSize = CGSize.zero
    
    var scaledThumbnailSize = CGSize.zero
    
    var assets: [PHAsset] = []
    
    var database: Database!
    
    var listener: URLEndpointListener!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initPhotos()
    }
    
    func initPhotos() {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
            case .authorized:
                start()
            case .restricted, .denied:
                print("Photo authorization is restricted or denied")
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization { (status) in
                    if status == .authorized {
                        self.start()
                    } else {
                        print("Photo authorization is restricted or denied")
                    }
            }
            default:
                print("Unknown authorization status")
        }
    }
    
    func start() {
        do {
            try prepareDatabase()
        } catch let error as NSError {
            // TODO: This is wrong
            AppDelegate.showMessage("Cannot get a database with error : \(error.code)", title: "Error", on: self)
            self.navigationController?.dismiss(animated: true, completion: {})
            return
        }
        
        do {
            try startListener()
        } catch let error as NSError {
            // TODO: This is wrong
            AppDelegate.showMessage("Cannot start listener with error : \(error.code)", title: "Error", on: self)
            self.navigationController?.dismiss(animated: true, completion: {})
            return
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let imageSize = (collectionView.bounds.width - 32) / 3
        thumbnailSize = CGSize(width: imageSize, height: imageSize)
        
        let scale = UIScreen.main.scale
        scaledThumbnailSize = CGSize(width: thumbnailSize.width * scale, height: thumbnailSize.height * scale)
        
        let layout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        layout.itemSize = thumbnailSize
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        layout.sectionInset = UIEdgeInsets.init(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)
    }
    
    // MARK: - Action

    @IBAction func cancelAction(_ sender: AnyObject) {
        self.navigationController?.dismiss(animated: true, completion: {
            self.listener.stop()
            self.deleteDatabase()
        })
    }
    
    // MARK: - Database
    
    func prepareDatabase() throws {
        database = try Database.init(name: "db")
        if (database.count > 0) {
            try database.delete()
            database = try Database.init(name: "db")
        }
        
        database.addChangeListener { (change) in
            // Add photo to library
            for id in change.documentIDs {
                if let doc = self.database.document(withID: id) {
                    let blob = doc.blob(forKey: "photo")!
                    self.addPhoto(data: blob.content!)
                }
            }
        }
    }
    
    func addPhoto(data: Data) {
        var id: String!
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
            id = request.placeholderForCreatedAsset!.localIdentifier
        }) { (success, error) in
            if (success) {
                let result = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
                if result.count > 0 {
                    self.assets.append(result[0])
                    DispatchQueue.main.async {
                        self.collectionView.reloadData()
                    }
                }
            } else {
                if let err = error as NSError? {
                    NSLog("Cannot save the photo with error : ", err.description)
                }
            }
        }
    }

    func deleteDatabase() {
        do {
            try database.delete()
        } catch let error as NSError {
            NSLog("Cannot delete the database with error : ", error.description)
        }
    }
    
    // MARK: - Listener
    
    func startListener() throws {
        let config = URLEndpointListenerConfiguration.init(database: database)
        config.disableTLS = true
        listener = URLEndpointListener.init(config: config)
        try listener.start()
        
        let url = listener.urls![0]
        print("URL: \(url.absoluteString)")
        imageView.image = UIImage.qrCodeImageForString(url.absoluteString, size: imageView.frame.size)
    }

    func secureGenerateKey(_ allowedCharacters: CharacterSet) -> String? {
        var data = Data(count: 32)
        let result = data.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
        }
        if result == errSecSuccess {
            return data.base64EncodedString()
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
    
}

extension ReceiveViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath) as! PhotoViewCell
        let asset = assets[indexPath.item]
        cell.assetId = asset.localIdentifier
        
        PHImageManager.default().requestImage(for: asset, targetSize: scaledThumbnailSize, contentMode: .aspectFill, options: nil) { (image: UIImage?, info: [AnyHashable: Any]?) -> Void in
            if cell.assetId == asset.localIdentifier {
                cell.imageView.image = image
                cell.checked = false
            }
        }
        
        return cell
    }
}
