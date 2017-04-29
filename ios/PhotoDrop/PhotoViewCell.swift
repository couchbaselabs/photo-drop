//
//  PhotoViewCell.swift
//  PhotoDrop
//
//  Created by Pasin Suriyentrakorn on 11/14/14.
//  Copyright (c) 2014 Couchbase. All rights reserved.
//

import UIKit

class PhotoViewCell: UICollectionViewCell {

    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var checkedImageView: UIImageView!

    var _checked: Bool!
    var checked: Bool {
        get {
            return _checked
        }
        set(value) {
            _checked = value
            if checkedImageView != nil {
                checkedImageView.isHidden = !value
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        self.checked = false
    }
}
