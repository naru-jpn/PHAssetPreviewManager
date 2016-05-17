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
public enum PHAssetPreviewResultType {
    case Image
    case ProgressImage
    case AnimationImages
    case Failed
    case Unknown
}

/// Result object to fetch asset image.
public class PHAssetPreviewResult {
    
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
    var requestProgressImages: Bool = false
    var sliceInterval: CGFloat = 0.1
    var range: Float64 = 1.0
    var progressHandler: ((progress: Double) -> Void)?
    
    var description: String {
        return "\(sliceInterval).\(range)"
    }
}

public typealias PHAssetPreviewRequestID = String

private typealias Handler = (result: PHAssetPreviewResult) -> Void

private struct VideoPreviewRequest {
    
    let requestID: PHAssetPreviewRequestID
    let asset: AVAsset
    let targetSize: CGSize
    let options: PHAssetPreviewRequestOptions
    let times: [NSValue]
    let handler: Handler?
}

/// Manager class for fetching image for asset.
/// You should call PHAssetImageFetchManager.sharedManager when fetching image.
class PHAssetPreviewManager: NSObject {
    
    internal static let sharedManager = PHAssetPreviewManager()
    
    private var processingVideoPreviewRequest: VideoPreviewRequest? = nil
    private var waitingVideoPreviewRequests = [VideoPreviewRequest]()
    
//    var processingImageGenerator = [String: AVAssetImageGenerator]()
//    var processingRequestID = [String: PHImageRequestID]()
    
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
        
        let requestID = String.init(format: "\(asset.localIdentifier).%5.1.%5.1.\(options)", targetSize.width, targetSize.height)
        let degradedRequestID = String.init(format: "\(asset.localIdentifier).%5.1.%5.1.\(options).degraded", targetSize.width, targetSize.height)
        
        // check if cached result is exist or not
        if let result = cachedResult(key: requestID) {
            resultHandler(result: result)
            return nil
        }
        
        // video
        if PHAssetMediaType.Video == asset.mediaType {
            
            let requestOptions = PHVideoRequestOptions()
            requestOptions.networkAccessAllowed = options.networkAccessAllowed
            PHImageManager.defaultManager().requestAVAssetForVideo(asset, options: requestOptions, resultHandler: { asset, audioMix, info in
              
                guard let asset = asset else {
                    print("Failed to get avasset.")
                    return
                }
                
                // degraded preview
                if options.requestDegradedResult {
                    self.requestVideoDegradedPreview(asset: asset, requestID: degradedRequestID, targetSize: targetSize, resultHandler: resultHandler)
                }
                
                // get preview
                objc_sync_enter(self)
                self.requestVideoPreview(asset: asset, requestID: requestID, targetSize: targetSize, options: options, resultHandler: resultHandler)
                objc_sync_exit(self)
            })
            
        // image
        } else if PHAssetMediaType.Image == asset.mediaType {
            
            if let cachedResult = self.cachedResult(key: requestID) {
                
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
                            
                            self.cache.setObject(result, forKey: requestID)
                        })
                    }
                }
            }
        }
        
        return requestID
    }
    
    // MARK: request video preview
    
    private func requestVideoDegradedPreview(asset asset: AVAsset, requestID: PHAssetPreviewRequestID, targetSize: CGSize, resultHandler: (result: PHAssetPreviewResult) -> Void) {
        
        if let cachedResult = self.cachedResult(key: requestID) {
            
            // found cached result
            dispatch_async(dispatch_get_main_queue(), {
                resultHandler(result: cachedResult)
            })
            
        } else {
            
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.maximumSize = targetSize
            imageGenerator.appliesPreferredTrackTransform = true
            
            // get preview thumbnial image
            var time = asset.duration
            time.value = 2
            
            do {
                let imageRef = try imageGenerator.copyCGImageAtTime(time, actualTime: nil)
                let image = UIImage(CGImage: imageRef)
                dispatch_async(dispatch_get_main_queue(), {
                    
                    let result = PHAssetPreviewResult(image: image, degraded: true, requestID: requestID)
                    resultHandler(result: result)
                    
                    self.cache.setObject(result, forKey: requestID)
                })
            } catch let error {
                print("Image generation failed with error \(error)")
            }
        }
    }
    
    private func requestVideoPreview(asset asset: AVAsset, requestID: PHAssetPreviewRequestID, targetSize: CGSize, options: PHAssetPreviewRequestOptions, resultHandler: (result: PHAssetPreviewResult) -> Void) {
        
        if let cachedResult = self.cachedResult(key: requestID) {
            
            debugPrint("\(requestID): found preview cache")
            
            // found cached result
            dispatch_async(dispatch_get_main_queue(), {
                resultHandler(result: cachedResult)
            })
            
        } else {
            
            debugPrint("\(requestID): prepare generating preview")
            
            // create request
            
            let duration: Float64 = CMTimeGetSeconds(asset.duration)
            let slice: Int = Int(floor(duration/Float64(options.sliceInterval)))
            let interval: Float64 = duration/Float64(slice)
            let times: [NSValue] = (0..<slice).filter {
                return Float64($0)*interval <= options.range
            }.map { index in
                return NSValue(CMTime: CMTimeMakeWithSeconds(interval*Float64(index), Int32(NSEC_PER_SEC)))
            }
            
            let request = VideoPreviewRequest(requestID: requestID, asset: asset, targetSize: targetSize, options: options, times: times, handler: resultHandler)
            
            if let _ = self.waitingVideoPreviewRequest(requestID: requestID) {
                print("replace?")
                self.replaceVideoPreviewRequest(requestID: requestID, request: request)
            } else {
                print("add")
                self.waitingVideoPreviewRequests.append(request)
            }
            
            self.handleRequestVideoPreview()
        }
    }
    
    private func handleRequestVideoPreview() {
        
        if let _ = self.processingVideoPreviewRequest {
            return
        }
        
        guard let request: VideoPreviewRequest = self.waitingVideoPreviewRequests.first else {
            return
        }
        self.processingVideoPreviewRequest = request
        
        let imageGenerator = AVAssetImageGenerator(asset: request.asset)
        imageGenerator.maximumSize = request.targetSize
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = kCMTimeZero
        imageGenerator.requestedTimeToleranceAfter = kCMTimeZero
        
        var images = [[String: AnyObject]]()
        imageGenerator.generateCGImagesAsynchronouslyForTimes(request.times) { requestedTime, cgImage, actualTime, imageGeneratorResult, error in
            
            if nil != error {
                print("Error occured at generating images: \(error)")
                imageGenerator.cancelAllCGImageGeneration()
                self.waitingVideoPreviewRequests.removeFirst()
                self.processingVideoPreviewRequest = nil
                self.handleRequestVideoPreview()
                return
            }
            
            if let cgImage = cgImage {
                
                let image = UIImage(CGImage: cgImage, scale: 1.0, orientation: .Up)
                images.append(["time": Float(CMTimeGetSeconds(actualTime)), "image": image])
                
                // return progress image
                if request.options.requestProgressImages {
                    dispatch_async(dispatch_get_main_queue(), {
                        if let processingRequest = self.processingVideoPreviewRequest {
                            let result = PHAssetPreviewResult(progressImage: image, requestID: request.requestID)
                            processingRequest.handler?(result: result)
                        }
                    })
                }
                
                if images.count == request.times.count {
                    
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
                        let result = PHAssetPreviewResult(animationImages: animationImages, requestID: request.requestID)
                        if let processingRequest = self.processingVideoPreviewRequest {
                            processingRequest.handler?(result: result)
                        }
                        
                        debugPrint("\(request.requestID): finish request preview")
                        
                        self.cache.setObject(result, forKey: request.requestID)
                    })
                    
                    self.waitingVideoPreviewRequests.removeFirst()
                    self.processingVideoPreviewRequest = nil
                    self.handleRequestVideoPreview()
                }
            }
        }
    }
    
    private func waitingVideoPreviewRequest(requestID requestID: PHAssetPreviewRequestID) -> VideoPreviewRequest? {
        
        var result: VideoPreviewRequest? =  nil
        waitingVideoPreviewRequests.enumerate().forEach { (index: Int, element: VideoPreviewRequest) in
            if element.requestID == requestID {
                result = element
                return
            }
        }
        return result
    }
    
    private func replaceVideoPreviewRequest(requestID requestID: PHAssetPreviewRequestID, request: VideoPreviewRequest) {
        
        waitingVideoPreviewRequests.enumerate().forEach { (index: Int, element: VideoPreviewRequest) in
            if element.requestID == requestID {
                self.waitingVideoPreviewRequests.removeAtIndex(index)
                print("\(waitingVideoPreviewRequests.count) \(index)")
                let _index = self.waitingVideoPreviewRequests.count > 0 ? 1 : 0
                self.waitingVideoPreviewRequests.insert(request, atIndex: _index)
                print("\(self.processingVideoPreviewRequest?.requestID) \(request.requestID)")
                if self.processingVideoPreviewRequest?.requestID == request.requestID {
                    self.processingVideoPreviewRequest = request
                }
                return
            }
        }
        
        
    }
    
    // MARK: - cancel
    
    func cancelRequest(requestID: PHAssetPreviewRequestID) {
        
//        if let imageGenerator = self.processingImageGenerator[requestID] {
//            imageGenerator.cancelAllCGImageGeneration()
//            self.processingImageGenerator[requestID] = nil
//        }
//        if let imageRequestID = self.processingRequestID[requestID] {
//            PHImageManager.defaultManager().cancelImageRequest(imageRequestID)
//            self.processingRequestID[requestID] = nil
//        }
    }
    
}
