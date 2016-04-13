//
//  PHCachingAssetPreviewManager.swift
//  FetchVideo
//
//  Created by naru on 2016/04/06.
//  Copyright © 2016年 naru. All rights reserved.
//

import Photos
import Foundation

class PHCachingAssetPreviewManager: PHAssetPreviewManager {
    
    internal static let sharedCachingManager = PHCachingAssetPreviewManager()
    
    private var cachingAssetPreviewRequests = [(requestID: PHAssetPreviewRequestID, asset: PHAsset)]()
    
    /// Start to cache asset previews for assets
    /// - parameter assets: assets to cache result
    /// - parameter targetSize: size to cache result for asset previews
    /// - parameter options: options to get asset previews
    func startCachingPreviewForAssets(assets: [PHAsset], targeSize: CGSize, options: PHAssetPreviewRequestOptions) {
        // start cache for all assets
        for asset in assets {
            if let requestID = PHAssetPreviewManager.sharedManager.requestAssetPreview(asset: asset, targetSize: targeSize, options: options, resultHandler: { result in
                                
                // remove caching request id
                let removedRequests = self.cachingAssetPreviewRequests.filter { request in
                    return request.requestID == result.requestID
                }
                self.stopCachingPreviewForRequests(removedRequests)
            }) {
                // store caching request id
                cachingAssetPreviewRequests.append((requestID: requestID, asset: asset))
            }
        }
    }
    
    func requestIDForAsset(asset: PHAsset) -> PHAssetPreviewRequestID? {
        for request in cachingAssetPreviewRequests {
            if request.asset == asset {
                return request.requestID
            }
        }
        return nil
    }
    
    /// Stop to cache asset previews for requests
    func stopCachingPreviewForRequests(requests: [(requestID: PHAssetPreviewRequestID, asset: PHAsset)]) {
        // cancel request and remove from array of request
        for request in requests {
            PHAssetPreviewManager.sharedManager.cancelRequest(request.requestID)
            cachingAssetPreviewRequests = cachingAssetPreviewRequests.filter { _request in
                return _request.requestID == request.requestID
            }
        }
    }
    
    /// Stop to cache asset previews for assets
    func stopCachingPreviewForAssets(assets: [PHAsset]) {
        // create array of request
        let requests = assets.flatMap { asset -> (requestID: PHAssetPreviewRequestID, asset: PHAsset)? in
            if let requestID = requestIDForAsset(asset) {
                return (requestID, asset) as (requestID: PHAssetPreviewRequestID, asset: PHAsset)
            }
            return nil
        }
        stopCachingPreviewForRequests(requests)
    }
    
    /// Stop to cache all asset previews
    func stopCachingPreviewForAllAssets() {
        // stop caching asset previews
        for request in cachingAssetPreviewRequests {
            PHAssetPreviewManager.sharedManager.cancelRequest(request.requestID)
        }
        cachingAssetPreviewRequests = [(requestID: PHAssetPreviewRequestID, asset: PHAsset)]()
    }
}

