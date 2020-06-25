//
//  PhotoViewCell.swift
//  PhotoDrop
//
//  Created by Pasin Suriyentrakorn on 11/14/14.
//  Copyright (c) 2014 Couchbase. All rights reserved.
//

import UIKit

class PhotoViewCell: UICollectionViewCell {
    @IBOutlet weak var checkedImageView: UIImageView!
    @IBOutlet weak var imageView: UIImageView!
    
    public var checked: Bool = false {
        willSet(newValue) {
            if checkedImageView != nil {
                checkedImageView.isHidden = !newValue
            }
        }
    }
}
