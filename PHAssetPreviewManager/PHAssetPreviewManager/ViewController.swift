//
//  ViewController.swift
//  FecthVideo
//
//  Created by naru on 2016/03/31.
//  Copyright © 2016年 naru. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UICollectionViewDelegate {

    var _collectionview: UICollectionView?
    let dataSource: FetchVideoDataSource = FetchVideoDataSource()
    
    var collectionViewItemSize: CGSize {
        let margin: CGFloat = 1.0
        let columns: Int = 3
        let width = (UIScreen.mainScreen().bounds.size.width - margin*CGFloat(columns - 1))/CGFloat(columns)
        return CGSizeMake(width, width)
    }
    
    var collectionView: UICollectionView {
        if let collectionview = _collectionview {
            return collectionview
        }
        
        let margin: CGFloat = 1.0
        let columns: Int = 3
        let width = (UIScreen.mainScreen().bounds.size.width - margin*CGFloat(columns - 1))/CGFloat(columns)
        let itemSize = CGSizeMake(width, width)
        
        let collectionViewLayout = UICollectionViewFlowLayout()
        collectionViewLayout.itemSize = itemSize
        collectionViewLayout.minimumInteritemSpacing = margin
        collectionViewLayout.minimumLineSpacing = margin
        collectionViewLayout.scrollDirection = .Vertical
        
        let collectionview = UICollectionView(frame: self.view.bounds, collectionViewLayout: collectionViewLayout)
        collectionview.registerClass(FetchVideoCollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        collectionview.backgroundColor = UIColor.whiteColor()
        collectionview.dataSource = dataSource
        collectionview.delegate = self
        collectionview.alwaysBounceVertical = true
        return collectionview
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(collectionView)
        
        let scale = UIScreen.mainScreen().scale
        let targetSize = CGSizeMake(collectionViewItemSize.width*scale, collectionViewItemSize.height*scale)
        
        // cache 
//        var options = PHAssetPreviewRequestOptions()
//        options.networkAccessAllowed = true
//        options.requestDegradedResult = true
//        options.requestProgressImages = false
//        options.sliceInterval = 0.03
//        options.range = 1.0
//        PHCachingAssetPreviewManager.sharedCachingManager.startCachingPreviewForAssets(dataSource.assets, targeSize: targetSize, options: options)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func collectionView(collectionView: UICollectionView, didEndDisplayingCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
        if let cell = cell as? FetchVideoCollectionViewCell {
            cell.cancelImageRequest()
            cell.unsetup()
        }
    }
}