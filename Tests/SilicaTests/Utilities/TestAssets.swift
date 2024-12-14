//
//  TestAssets.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/6/17.
//
//

import Foundation
import Silica
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct TestAsset: Equatable, Hashable {
    
    let url: URL
    let filename: String
}

final class TestAssetManager <HTTPClient: URLClient> {
    
    let assets: [TestAsset]
    
    let cacheDirectory: URL
    
    let httpClient: HTTPClient
    
    private(set) var downloadedAssets = [TestAsset]()
    
    init(assets: [TestAsset], cacheDirectory: URL, httpClient: HTTPClient) {
        
        self.assets = assets
        self.cacheDirectory = cacheDirectory
        self.httpClient = httpClient
    }
    
    public func fetchAssets(skipCached: Bool = true) async throws {
        
        let httpClient = self.httpClient
        
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
            
            let request = URLRequest(url: asset.url)
            
            let (data, response) = try await httpClient.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                fatalError()
            }
            
            guard httpResponse.statusCode == 200
                else { throw Error.invalidStatusCode(httpResponse.statusCode) }
                        
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
    
    func cachedImage(named name: String) -> CGImage? {
        let fileURL = cacheURL(for: name)
        guard let data = try? Data(contentsOf: fileURL),
            let imageSource = CGImageSourcePNG(data: data),
            let image = imageSource.createImage(at: 0)
            else { return nil }
        return image
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
        guard let image = TestAssetManager.shared.cachedImage(named: name) else {
            return nil
        }
        self.init(cgImage: image)
    }
}
