//
//  PHAssetPreviewManager.swift
//  FetchVideo
//
//  Created by naru on 2016/04/01.
//  Copyright © 2016年 naru. All rights reserved.
//

import UIKit
import Photos

/// Type of result to fetch asset image.
enum PHAssetPreviewResultType {
    case Image
    case ProgressImage
    case AnimationImages
    case Failed
    case Unknown
}

/// Result object to fetch asset image.
class PHAssetPreviewResult {
    
    let degraded: Bool
    let type: PHAssetPreviewResultType
    var image: UIImage? = nil
    var animationImages: [UIImage]? = nil
    var requestID: PHAssetPreviewRequestID = ""
    
    init(image: UIImage, degraded: Bool, requestID: PHAssetPreviewRequestID) {
        self.degraded = degraded
        self.type = .Image
        self.image = image
        self.requestID = requestID
    }
    
    init(progressImage: UIImage, requestID: PHAssetPreviewRequestID) {
        self.degraded = true
        self.type = .ProgressImage
        self.image = progressImage
        self.requestID = requestID
    }
    
    init(animationImages: [UIImage], requestID: PHAssetPreviewRequestID) {
        self.degraded = false
        self.type = .AnimationImages
        self.animationImages = animationImages
        self.requestID = requestID
    }
    
    var description: String {
        return "\(self), type: \(type), image: \(image), animationImages: \(animationImages)"
    }
}

/// Options to request asset preview.
struct PHAssetPreviewRequestOptions: CustomStringConvertible {
    var networkAccessAllowed: Bool = false
    var requestDegradedResult: Bool = true
    var requestProgressImages: Bool = true
    var sliceInterval: CGFloat = 0.1
    var range: Float64 = 1.0
    var progressHandler: ((progress: Double) -> Void)?
    
    var description: String {
        return "\(sliceInterval).\(range)"
    }
}

typealias PHAssetPreviewRequestID = String

/// Manager class for fetching image for asset.
/// You should call PHAssetImageFetchManager.sharedManager when fetching image.
class PHAssetPreviewManager: NSObject {
    
    internal static let sharedManager = PHAssetPreviewManager()
    
    var processingImageGenerator = [String: AVAssetImageGenerator]()
    var processingRequestID = [String: PHImageRequestID]()
    
    // MARK: - cache
    
    let cache = NSCache()
    
    func cacheResult(result result: PHAssetPreviewResult, key: String) {
        self.cache.setObject(result, forKey: key)
    }
    
    func cachedResult(key key: String) -> PHAssetPreviewResult? {
        return self.cache.objectForKey(key) as? PHAssetPreviewResult
    }
    
    // MARK: - request image
    
    func requestAssetPreview(asset asset: PHAsset, targetSize: CGSize, options: PHAssetPreviewRequestOptions, resultHandler: (result: PHAssetPreviewResult) -> Void) ->  PHAssetPreviewRequestID? {
        
        let cacheKey = String.init(format: "\(asset.localIdentifier).%5.1.%5.1.\(options)", targetSize.width, targetSize.height)
        let degradedCacheKey = String.init(format: "\(asset.localIdentifier).%5.1.%5.1.\(options).degraded", targetSize.width, targetSize.height)
        
        // check if cached result is exist or not
        if let result = cachedResult(key: cacheKey) {
            resultHandler(result: result)
            return nil
        }
        
        let requestID = NSUUID().UUIDString
        
        // video
        if PHAssetMediaType.Video == asset.mediaType {
            
            let requestOptions = PHVideoRequestOptions()
            requestOptions.networkAccessAllowed = options.networkAccessAllowed
            PHImageManager.defaultManager().requestAVAssetForVideo(asset, options: requestOptions, resultHandler: { asset, audioMix, info in
              
                guard let asset = asset else {
                    print("Failed to get avasset.")
                    return
                }
                
                // get image generator
                if let imageGenerator = self.processingImageGenerator[requestID] {
                    imageGenerator.cancelAllCGImageGeneration()
                    self.processingImageGenerator[requestID] = nil
                }
                let degradedImageGenerator = AVAssetImageGenerator(asset: asset)
                self.processingImageGenerator[requestID] = degradedImageGenerator
                
                // degraded preview
                if options.requestDegradedResult {
                    
                    if let cachedResult = self.cachedResult(key: degradedCacheKey) {
                        
                        // found cached result
                        dispatch_async(dispatch_get_main_queue(), {
                            resultHandler(result: cachedResult)
                        })
                        
                    } else {
                        
                        degradedImageGenerator.maximumSize = targetSize
                        degradedImageGenerator.appliesPreferredTrackTransform = true
                        
                        // get preview thumbnial image
                        var time = asset.duration
                        time.value = 2
                       
                        do {
                            let imageRef = try degradedImageGenerator.copyCGImageAtTime(time, actualTime: nil)
                            let image = UIImage(CGImage: imageRef)
                            dispatch_async(dispatch_get_main_queue(), {
                                
                                let result = PHAssetPreviewResult(image: image, degraded: true, requestID: requestID)
                                resultHandler(result: result)
                                
                                self.cache.setObject(result, forKey: degradedCacheKey)
                            })
                        } catch let error {
                            print("Image generation failed with error \(error)")
                        }
                    }
                }
                
                // get preview
                if let imageGenerator = self.processingImageGenerator[requestID] {
                    
                    if let cachedResult = self.cachedResult(key: cacheKey) {
                        
                        debugPrint("found cache : \(cacheKey)")
                        
                        // found cached result
                        dispatch_async(dispatch_get_main_queue(), {
                            resultHandler(result: cachedResult)
                        })
                        
                    } else {
                        
                        debugPrint("generating: \(cacheKey)")
                        
                        imageGenerator.maximumSize = targetSize
                        imageGenerator.appliesPreferredTrackTransform = true
                        imageGenerator.requestedTimeToleranceBefore = kCMTimeZero
                        imageGenerator.requestedTimeToleranceAfter = kCMTimeZero
                        
                        let duration = CMTimeGetSeconds(asset.duration)
                        let slice = Int(floor(duration/Float64(options.sliceInterval)))
                        let interval: Float64 = duration/Float64(slice)
                        let times: [NSValue] = (0..<slice).filter {
                            return Float64($0)*interval <= options.range
                        }.map { index in
                            return NSValue(CMTime: CMTimeMakeWithSeconds(interval*Float64(index), Int32(NSEC_PER_SEC)))
                        }
                        
                        var images = [[String: AnyObject]]()
                        imageGenerator.generateCGImagesAsynchronouslyForTimes(times) { requestedTime, cgImage, actualTime, imageGeneratorResult, error in
                                                        
                            if nil != error {
                                print("Error occured at generating images: \(error)")
                                return
                            }
                            
                            if let cgImage = cgImage {

                                let image = UIImage(CGImage: cgImage, scale: 1.0, orientation: .Up)
                                images.append(["time": Float(CMTimeGetSeconds(actualTime)), "image": image])
                                
                                // return progress image
                                if options.requestProgressImages {
                                    dispatch_async(dispatch_get_main_queue(), {
                                        let result = PHAssetPreviewResult(progressImage: image, requestID: requestID)
                                        resultHandler(result: result)
                                    })
                                }
                                
                                if images.count == times.count {
                                    let animationImages: [UIImage] = images.sort {
                                        let time1 = $0["time"] as! Float
                                        let time2 = $1["time"] as! Float
                                        return time1 < time2
                                    }.flatMap {
                                        let image = $0["image"] as! UIImage
                                        return image
                                    }
                                    dispatch_async(dispatch_get_main_queue(), {
                                        // return animation images
                                        let result = PHAssetPreviewResult(animationImages: animationImages, requestID: requestID)
                                        resultHandler(result: result)
    
                                        debugPrint("key: \(cacheKey)")
                                        
                                        self.cache.setObject(result, forKey: cacheKey)
                                    })
                                    self.processingImageGenerator[requestID] = nil
                                }
                            }
                        }
                    }
                }
                
            })
            
        // image
        } else if PHAssetMediaType.Image == asset.mediaType {
            
            if let cachedResult = self.cachedResult(key: cacheKey) {
                
                // found cached result
                dispatch_async(dispatch_get_main_queue(), {
                    resultHandler(result: cachedResult)
                })
                
            } else {
                
                let options = PHImageRequestOptions()
                
                let imageManager = PHImageManager.defaultManager()
                imageManager.requestImageForAsset(asset, targetSize: targetSize, contentMode: .AspectFill, options: options) { image, options in
                    
                    if let image = image {
                        
                        dispatch_async(dispatch_get_main_queue(), {
                            
                            let result = PHAssetPreviewResult(image: image, degraded: false, requestID: requestID)
                            resultHandler(result: result)
                            
                            self.cache.setObject(result, forKey: cacheKey)
                        })
                    }
                }
            }
        }
        
        return requestID
    }
    
    func cancelRequest(requestID: PHAssetPreviewRequestID) {
        if let imageGenerator = self.processingImageGenerator[requestID] {
            imageGenerator.cancelAllCGImageGeneration()
            self.processingImageGenerator[requestID] = nil
        }
        if let imageRequestID = self.processingRequestID[requestID] {
            PHImageManager.defaultManager().cancelImageRequest(imageRequestID)
            self.processingRequestID[requestID] = nil
        }
    }
    
}
