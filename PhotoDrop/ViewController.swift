//
//  ViewController.swift
//  PhotoDrop
//
//  Created by Pasin Suriyentrakorn on 6/18/20.
//  Copyright © 2020 Pasin Suriyentrakorn. All rights reserved.
//

import UIKit
import Photos

class PhotosViewController: UIViewController {
    @IBOutlet weak var collectionView: UICollectionView!
    
    var thumbnailSize: CGSize = CGSize.zero
    
    var assets: PHFetchResult<PHAsset>?
    
    var selectedAssets: [PHAsset] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initPhotos()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let imageSize = (collectionView.bounds.width - 32) / 3
        thumbnailSize = CGSize(width: imageSize, height: imageSize)
        
        let layout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        layout.itemSize = thumbnailSize
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        layout.sectionInset = UIEdgeInsets.init(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)
    }
    
    func initPhotos() {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
            case .authorized:
                reloadPhotos()
            case .restricted, .denied:
                print("Photo authorization is restricted or denied")
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization { (status) in
                    if status == .authorized {
                        self.reloadPhotos()
                    } else {
                        print("Photo authorization is restricted or denied")
                    }
            }
            default:
                print("Unknown authorization status")
        }
    }
    
    func reloadPhotos() {
        if assets == nil {
            let allPhotosOptions = PHFetchOptions()
            allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            assets = PHAsset.fetchAssets(with: allPhotosOptions)
            collectionView.reloadData()
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
        return collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell",
            for: indexPath) as! PhotoViewCell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let asset = assets!.object(at: indexPath.row)
        PHImageManager.default().requestImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFill, options: nil) { (image: UIImage?, info: [AnyHashable: Any]?) -> Void in
            let photoViewCell = cell as! PhotoViewCell
            photoViewCell.imageView.image = image
            photoViewCell.checked = self.selectedAssets.contains(asset)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let asset = assets!.object(at: indexPath.row)
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
