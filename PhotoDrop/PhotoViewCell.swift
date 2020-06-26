//
//  PhotoViewCell.swift
//  PhotoDrop
//
//  Created by Pasin Suriyentrakorn
//  Copyright (c) 2020 Couchbase. All rights reserved.
//

import UIKit

class PhotoViewCell: UICollectionViewCell {
    @IBOutlet weak var checkedImageView: UIImageView!
    
    @IBOutlet weak var imageView: UIImageView!
    
    var assetId: String!
    
    public var checked: Bool = false {
        willSet(newValue) {
            if checkedImageView != nil {
                checkedImageView.isHidden = !newValue
            }
        }
    }
}
