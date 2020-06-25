//
//  ViewController.swift
//  PhotoDrop
//
//  Created by Pasin Suriyentrakorn on 11/14/14.
//  Copyright (c) 2014 Couchbase. All rights reserved.
//

import UIKit
import AssetsLibrary

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    @IBOutlet weak var collectionView: UICollectionView!

    var library: ALAssetsLibrary!

    var assets:[ALAsset] = []

    var selectedAssets:[ALAsset] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: nil) { (notification) -> Void in
                self.reloadAssets()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        enableSendMode(false)
        reloadAssets()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated);
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "send" {
            let navigationController = segue.destination as! UINavigationController
            let controller = navigationController.topViewController as! SendViewController
            controller.sharedAssets = selectedAssets
        }
    }

    // MARK: - Navigation Bar

    func enableSendMode(_ enabled: Bool) {
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

    // MARK: - ALAssetsLibrary

    func reloadAssets() {
        if library == nil {
            library = ALAssetsLibrary()
        }

        assets = [];
        selectedAssets = [];

        library.enumerateGroups(withTypes: ALAssetsGroupType(ALAssetsGroupSavedPhotos), using: { (group, stop) in
            guard let group = group else {
                DispatchQueue.main.async(execute: {
                    self.collectionView.reloadData()
                })
                return
            }
           
            group.setAssetsFilter(ALAssetsFilter.allPhotos())
            group.enumerateAssets({ (asset, index, stop) in
                if asset != nil {
                    self.assets.append(asset!)
                }
            })
      
        }) { (error) in
            
        }
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
        cell.checked = selectedAssets.contains(asset)
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

    func collectionView(_ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! PhotoViewCell
        let asset = assets[indexPath.row]
        if let foundIndex = selectedAssets.index(of: asset) {
            selectedAssets.remove(at: foundIndex)
            cell.checked = false
        } else {
            selectedAssets.append(asset)
            cell.checked = true
        }
        collectionView.reloadItems(at: [indexPath])

        self.enableSendMode(selectedAssets.count > 0)
    }
}

