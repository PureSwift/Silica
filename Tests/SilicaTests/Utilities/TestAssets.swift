//
//  TestAssets.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/6/17.
//
//

import Foundation
import Silica

struct TestAsset {
    
    let url: URL
    let filename: String
}

extension TestAsset: Equatable {
    
    static func ==(lhs: TestAsset, rhs: TestAsset) -> Bool {
        
        return lhs.url == rhs.url
            && lhs.filename == rhs.filename
    }
}

extension TestAsset: Hashable {
    
    var hashValue: Int {
        
        return (url.absoluteString + filename).hashValue
    }
}

final class TestAssetManager {
    
    init(assets: [TestAsset], cacheDirectory: URL) {
        
        self.assets = assets
        self.cacheDirectory = cacheDirectory
    }
    
    let assets: [TestAsset]
    
    let cacheDirectory: URL
    
    let httpClient = HTTP.Client()
    
    private(set) var downloadedAssets = [TestAsset]()
    
    func fetchAssets(skipCached: Bool = true) throws {
        
        for asset in assets {
            
            // get destination file path
            let fileURL = cacheURL(for: asset.filename)
            
            // skip if already downloaded
            if skipCached {
                
                guard FileManager.default.fileExists(atPath: fileURL.path) == false
                    else { continue }
            }
            
            print("Fetching \(asset.filename)")
            
            // fetch data
            
            let request = HTTP.Request(url: asset.url)
            
            let response = try httpClient.send(request: request)
            
            guard response.statusCode == HTTP.StatusCode.OK.rawValue
                else { throw Error.invalidStatusCode(response.statusCode) }
            
            let data = response.body
            
            guard data.isEmpty == false
                else { throw Error.emptyData }
            
            // save to file system
            
            guard FileManager.default.createFile(atPath: fileURL.path, contents: data, attributes: nil)
                else { throw Error.fileWrite }
            
            downloadedAssets.append(asset)
            
            print("Downloaded \(asset.url.absoluteString)")
        }
    }
    
    func cacheURL(for assetFilename: String) -> URL {
        
        return cacheDirectory.appendingPathComponent(assetFilename)
    }
}

extension TestAssetManager {
    
    enum Error: Swift.Error {
        
        case invalidStatusCode(Int)
        case emptyData
        case fileWrite
    }
}

// MARK: - UIImage

extension UIImage {
    
    convenience init?(named name: String) {
        
        let fileURL = TestAssetManager.shared.cacheURL(for: name)
        
        guard let data = try? Data(contentsOf: fileURL),
            let imageSource = CGImageSourcePNG(data: data)
            else { return nil }
        
        let image = imageSource[0]
        
        self.init(cgImage: image)
    }
}
