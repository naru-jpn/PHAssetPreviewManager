//
//  FetchVideoCollectionViewCell.swift
//  FetchVideo
//
//  Created by naru on 2016/03/31.
//  Copyright © 2016年 naru. All rights reserved.
//

import UIKit
import Photos
import Foundation

class FetchVideoCollectionViewCell: UICollectionViewCell {
    
    var _imageView: UIImageView?
    var imageGenerator: AVAssetImageGenerator?
    var assetPreviewRequestID : PHAssetPreviewRequestID?
    
    var imageView: UIImageView {
        if let imageView = _imageView {
            return imageView
        }
        _imageView = UIImageView(frame: self.bounds)
        _imageView!.clipsToBounds = true
        _imageView!.contentMode = .ScaleAspectFill
        _imageView!.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        return _imageView!
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.userInteractionEnabled = false
        self.addSubview(imageView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func unsetup() {
        self.imageView.stopAnimating()
        self.imageView.animationImages = nil
        self.imageView.image = nil
    }
    
    func setAsset(asset asset: PHAsset) {
        
        let scale = UIScreen.mainScreen().scale
        let targetSize = CGSizeMake(self.frame.size.width*scale, self.frame.size.height*scale)
        var options = PHAssetPreviewRequestOptions()
        options.networkAccessAllowed = true
        options.requestDegradedResult = true
        options.sliceInterval = 0.03
        options.range = 1.0
        
        assetPreviewRequestID = PHAssetPreviewManager.sharedManager.requestAssetPreview(asset: asset, targetSize: targetSize, options: options) { result in
            
            self.unsetup()
                        
            if PHAssetPreviewResultType.Image == result.type {
                self.imageView.image = result.image
            } else if PHAssetPreviewResultType.ProgressImage == result.type {
                self.imageView.image = result.image
            } else if PHAssetPreviewResultType.AnimationImages == result.type {
                if let animationImages = result.animationImages {
                    self.imageView.animationImages = animationImages
                    self.imageView.animationDuration = NSTimeInterval(CGFloat(animationImages.count) * options.sliceInterval * 1.5)
                    self.imageView.animationRepeatCount = 0
                    self.imageView.startAnimating()
                }
            }
        }
    }
    
    func cancelImageRequest() {
        if let assetPreviewRequestID = assetPreviewRequestID {
            PHAssetPreviewManager.sharedManager.cancelRequest(assetPreviewRequestID)
        }
    }
}
