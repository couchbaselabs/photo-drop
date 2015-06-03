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

        NSNotificationCenter.defaultCenter().addObserverForName(
            UIApplicationWillEnterForegroundNotification,
            object: nil, queue: nil) { (notification) -> Void in
                self.reloadAssets()
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        enableSendMode(false)
        reloadAssets()
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated);
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "send" {
            let navigationController = segue.destinationViewController as! UINavigationController
            let controller = navigationController.topViewController as! SendViewController
            controller.sharedAssets = selectedAssets
        }
    }

    // MARK: - Navigation Bar

    func enableSendMode(enabled: Bool) {
        if enabled {
            let sendButtonItem = UIBarButtonItem(title: "Send",
                style: UIBarButtonItemStyle.Plain, target: self, action: "sendButtonAction:")
            self.navigationItem.rightBarButtonItem = sendButtonItem
        } else {
            self.navigationItem.rightBarButtonItem = nil
        }
    }

    func sendButtonAction(sender: AnyObject) {
        self.performSegueWithIdentifier("send", sender: self)
    }

    // MARK: - ALAssetsLibrary

    func reloadAssets() {
        if library == nil {
            library = ALAssetsLibrary()
        }

        assets = [];
        selectedAssets = [];

        library.enumerateGroupsWithTypes(ALAssetsGroupSavedPhotos, usingBlock:
            { (group:ALAssetsGroup!, stop:UnsafeMutablePointer<ObjCBool>) -> Void in
                if group != nil {
                    group.setAssetsFilter(ALAssetsFilter.allPhotos())
                    group.enumerateAssetsWithOptions(NSEnumerationOptions.Reverse,
                        usingBlock: { (asset:ALAsset!, index:Int,
                            stop: UnsafeMutablePointer<ObjCBool>) -> Void in
                            if asset != nil {
                                self.assets.append(asset)
                            }
                    })
                } else {
                    dispatch_async(dispatch_get_main_queue(), {
                        self.collectionView.reloadData()
                    })
                }
            }) { (error:NSError!) -> Void in
        }
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
        cell.checked = contains(selectedAssets, asset)
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

    func collectionView(collectionView: UICollectionView,
        didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let cell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoViewCell
        let asset = assets[indexPath.row]
        if let foundIndex = find(selectedAssets, asset) {
            selectedAssets.removeAtIndex(foundIndex)
            cell.checked = false
        } else {
            selectedAssets.append(asset)
            cell.checked = true
        }
        collectionView.reloadItemsAtIndexPaths([indexPath])

        self.enableSendMode(selectedAssets.count > 0)
    }
}

