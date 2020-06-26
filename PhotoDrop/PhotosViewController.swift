//
//  PhotosViewController.swift
//  PhotoDrop
//
//  Created by Pasin Suriyentrakorn.
//  Copyright © 2020 Pasin Suriyentrakorn. All rights reserved.
//

import UIKit
import Photos

class PhotosViewController: UIViewController {
    @IBOutlet weak var collectionView: UICollectionView!
    
    var dispatchQueue: DispatchQueue!
    
    var thumbnailSize = CGSize.zero
    
    var scaledThumbnailSize = CGSize.zero
    
    var assets: PHFetchResult<PHAsset>?
    
    var selectedAssets: [PHAsset] = []
    
    var didRegisterPhotosObserver = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dispatchQueue = DispatchQueue.init(label: "PhotosViewController")
        initPhotos()
    }
    
    deinit {
        unregisterPhotosObserver()
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "send" {
            let navigationController = segue.destination as! UINavigationController
            let controller = navigationController.topViewController as! SendViewController
            controller.assets = selectedAssets
        }
    }
    
    func initPhotos() {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
            case .authorized:
                registerPhotosObserver()
                reloadPhotos()
            case .restricted, .denied:
                print("Photo authorization is restricted or denied")
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization { (status) in
                    if status == .authorized {
                        self.registerPhotosObserver()
                        self.reloadPhotos()
                    } else {
                        print("Photo authorization is restricted or denied")
                    }
            }
            default:
                print("Unknown authorization status")
        }
    }
    
    func registerPhotosObserver() {
        if !didRegisterPhotosObserver {
            PHPhotoLibrary.shared().register(self)
            didRegisterPhotosObserver = true
        }
    }
    
    func unregisterPhotosObserver() {
        if didRegisterPhotosObserver {
            PHPhotoLibrary.shared().unregisterChangeObserver(self)
        }
    }
    
    func reloadPhotos() {
        dispatchQueue.async {
            let allPhotosOptions = PHFetchOptions()
            allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            self.assets = PHAsset.fetchAssets(with: allPhotosOptions)
            
            DispatchQueue.main.async {
                self.collectionView.reloadData()
            }
        }
    }
    
    func enableSendButton(enabled: Bool) {
        if enabled {
            let sendButtonItem = UIBarButtonItem(title: "Send",
                                                 style: UIBarButtonItem.Style.plain,
                                                 target: self,
                                                 action: #selector(sendButtonAction(sender:)))
            self.navigationItem.rightBarButtonItem = sendButtonItem
        } else {
            self.navigationItem.rightBarButtonItem = nil
        }
    }

    @objc func sendButtonAction(sender: AnyObject) {
        self.performSegue(withIdentifier: "send", sender: self)
    }
}

extension PhotosViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return (assets != nil) ? assets!.count : 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath) as! PhotoViewCell
        let asset = assets!.object(at: indexPath.item)
        cell.assetId = asset.localIdentifier
        
        PHImageManager.default().requestImage(for: asset, targetSize: scaledThumbnailSize, contentMode: .aspectFill, options: nil) { (image: UIImage?, info: [AnyHashable: Any]?) -> Void in
            if cell.assetId == asset.localIdentifier {
                cell.imageView.image = image
                cell.checked = self.selectedAssets.contains(asset)
            }
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let asset = assets!.object(at: indexPath.item)
        let cell = collectionView.cellForItem(at: indexPath) as! PhotoViewCell
        if let index = selectedAssets.firstIndex(of: asset) {
            selectedAssets.remove(at: index)
            cell.checked = false
        } else {
            selectedAssets.append(asset)
            cell.checked = true
        }
        collectionView.reloadItems(at: [indexPath])
        self.enableSendButton(enabled: selectedAssets.count > 0)
    }
}

extension PhotosViewController: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        self.reloadPhotos()
    }
}
