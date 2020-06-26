//
//  UIImage+Extension.swift
//  PhotoDrop
//
//  Created by Pasin Suriyentrakorn
//  Copyright (c) 2020 Couchbase. All rights reserved.
//

import UIKit

extension UIImage {

    class func qrCodeImageForString(_ string: String!, size: CGSize) -> UIImage? {
        // Create QR Code Image
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(string.data(using: String.Encoding.utf8,
                allowLossyConversion: false), forKey: "inputMessage")
            filter.setValue("H", forKey: "inputCorrectionLevel")
            let outputImage = filter.outputImage

            // Resize Image
            let cgImage = CIContext(options: nil).createCGImage(outputImage!,
                from: outputImage!.extent)
            let scale = UIScreen.main.scale

            UIGraphicsBeginImageContext(CGSize(width: size.width * scale, height: size.height))
            if let context = UIGraphicsGetCurrentContext() {
                context.interpolationQuality = CGInterpolationQuality.none;
                context.draw(cgImage!, in: context.boundingBoxOfClipPath)
                guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {return nil}
                UIGraphicsEndImageContext()

                if let resized = resizedImage.cgImage {
                    return UIImage(cgImage: resized, scale: scale,
                                   orientation: UIImage.Orientation.downMirrored)
                }
            }
        }
        return nil
    }

}
