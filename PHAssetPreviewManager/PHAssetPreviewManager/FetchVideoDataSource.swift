//
//  FetchVideoDataSource.swift
//  FecthVideo
//
//  Created by naru on 2016/03/31.
//  Copyright © 2016年 naru. All rights reserved.
//

import UIKit
import Foundation
import Photos

class FetchVideoDataSource: NSObject, UICollectionViewDataSource {
    
    var assets = [PHAsset]()
    
    override init() {
        super.init()
        
        fetchAssets()
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.assets.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        if let cell = collectionView.dequeueReusableCellWithReuseIdentifier("cell", forIndexPath: indexPath) as? FetchVideoCollectionViewCell {
            configure(cell: cell, indexPath: indexPath)
            return cell
        }
        return UICollectionViewCell()
    }
    
    func configure(cell cell: FetchVideoCollectionViewCell, indexPath: NSIndexPath) {
        let index = indexPath.row
        let asset = assets[index]
        cell.setAsset(asset: asset)
    }
    
    func fetchAssets() -> [PHAsset] {
        
        let options = PHFetchOptions()
        
        let prealbumCollectionsFetchResult = PHAssetCollection.fetchAssetCollectionsWithType(.Album, subtype: .AlbumRegular, options: options)
        prealbumCollectionsFetchResult.enumerateObjectsUsingBlock { collection, index, stop in
            if let collection = collection as? PHAssetCollection {
                let assetsFetchResult = PHAsset.fetchAssetsInAssetCollection(collection, options: options)
                assetsFetchResult.enumerateObjectsUsingBlock { asset, index, stop in
                    if let asset = asset as? PHAsset {
                        self.assets.append(asset)
                    }
                }
            }
        }
        
        let videoCollectionsFetchResult = PHAssetCollection.fetchAssetCollectionsWithType(.SmartAlbum, subtype: .SmartAlbumVideos, options: options)
        videoCollectionsFetchResult.enumerateObjectsUsingBlock { collection, index, stop in
            if let collection = collection as? PHAssetCollection {
                let assetsFetchResult = PHAsset.fetchAssetsInAssetCollection(collection, options: options)
                assetsFetchResult.enumerateObjectsUsingBlock { asset, index, stop in
                    if let asset = asset as? PHAsset {
                        self.assets.append(asset)
                    }
                }
            }
        }
        
//        let albumCollectionsFetchResult = PHAssetCollection.fetchAssetCollectionsWithType(.Album, subtype: .AlbumRegular, options: options)
//        albumCollectionsFetchResult.enumerateObjectsUsingBlock { collection, index, stop in
//            if let collection = collection as? PHAssetCollection {
//                let assetsFetchResult = PHAsset.fetchAssetsInAssetCollection(collection, options: options)
//                assetsFetchResult.enumerateObjectsUsingBlock { asset, index, stop in
//                    if let asset = asset as? PHAsset {
//                        self.assets.append(asset)
//                    }
//                }
//            }
//        }
        
        return assets
    }
}
