//
//  ViewController.swift
//  GifApp
//
//  Created by mac on 2021/2/7.
//

import UIKit
import AssetsLibrary
import NSGIF
import FLAnimatedImage
import MBProgressHUD
import TZImagePickerController


extension MainViewController: TZImagePickerControllerDelegate {}

class MainViewController: UIViewController {
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var selectButton: UIButton!
    var gifImageView: FLAnimatedImageView?
    var gifData: Data?
    var saveBarButtonItem: UIBarButtonItem?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = "GIF转换器"
        
        // 创建一个展示 GIF 图的视图
        gifImageView = FLAnimatedImageView(frame: view.bounds)
        gifImageView!.contentMode = .scaleAspectFit
        contentView.addSubview(gifImageView!)
        
        // 保存按钮
        saveBarButtonItem = UIBarButtonItem(title: "保存", style: .plain, target: self, action: #selector(saveAction(_:)))
        navigationItem.rightBarButtonItem = saveBarButtonItem
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        gifImageView?.frame = contentView.bounds
    }

    @IBAction func selectVideoAction(_ sender: UIButton) {
        let picker = TZImagePickerController(maxImagesCount: 1, columnNumber: 3, delegate: self)
        picker?.allowPickingImage = false   // 不能选择图片
        picker?.didFinishPickingVideoHandle = { (coverImage: UIImage?, asset: PHAsset?) in
            // 获取资源地址
            if asset != nil {
                PHImageManager.default().requestAVAsset(forVideo: asset!, options: PHVideoRequestOptions()) { (videoAsset, _, _) in
                    if videoAsset is AVURLAsset {
                        let url: URL = (videoAsset as! AVURLAsset).url
                        print("视频资源地址: \(url)")
                        // 生成 gif
                        self.createGif(url: url, duration: videoAsset!.duration.seconds)
                    } else {
                        self.showText(text: "视频格式不支持")
                    }
                }
            } else {
                self.showText(text: "资源不存在")
            }
        }
        
        present(picker!, animated: true, completion: nil)
    }
    
    @IBAction func cleanAction(_ sender: UIButton) {
        // 清空
        self.gifData = nil
        self.gifImageView?.animatedImage = nil
    }
    
    
    /// 显示文字
    /// - Parameter text: 文字
    func showText(text: String) {
        DispatchQueue.main.async {
            let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
            hud.label.text = text
            hud.mode = .text
            hud.hide(animated: true, afterDelay: 1)
        }
    }
    
    /// 生成 gif
    /// - Parameter url: 视频的文件地址
    func createGif(url: URL, duration: TimeInterval) {
        // hud 转菊花
        var hud: MBProgressHUD?
        DispatchQueue.main.async {
            hud = MBProgressHUD.showAdded(to: self.view, animated: true)
            hud!.label.text = "GIF 图片生成中..."
            hud!.mode = .indeterminate
        }
        // 调用 NSGIF 生成图片
        // 6fps
        NSGIF.createGIFfromURL(url, withFrameCount: Int32(ceil(6 * duration)), delayTime: 0, loopCount: 65535) { (gifUrl: URL?) in
            // hud 移除
            DispatchQueue.main.async {
                hud!.hide(animated: true)
            }
            if let url = gifUrl {
                // 展示图片
                self.gifData = NSData(contentsOf: url) as Data?
                let gifImage = FLAnimatedImage(animatedGIFData: self.gifData)
                DispatchQueue.main.async {
                    self.gifImageView?.animatedImage = gifImage
                }
            } else {
                self.showText(text: "GIF 转换失败❌")
            }
        }
    }
    
    
    @objc func saveAction(_ sender: UIBarButtonItem?) {
        if let data = self.gifData {
            // 保存
//            save(data: data, assetCollectionName: "GIF图库")
//            saveToPhotosAlbum(data: data)
            save(data: data)
        } else {
            showText(text: "请选择视频转换成GIF图片再保存")
        }
    }
    
    func save(data: Data) {
        let al = AssetsLibrary.ALAssetsLibrary()
        al.writeImageData(toSavedPhotosAlbum: data, metadata: nil) { (url, error) in
            if error == nil {
                self.showText(text: "保存成功")
            } else {
                self.showText(text: "保存失败")
            }
        }
    }
    
    
    /// 保存图片(会请求授权)
    /// - Parameters:
    ///   - data: 图片的二进制数据
    ///   - assetCollectionName: 相集名称
    func save(data: Data, assetCollectionName: String) {
        // 获取相册的授权状态
        let authorizationStatus = PHPhotoLibrary.authorizationStatus()
        // 判断状态
        if authorizationStatus == .authorized {
            // 已经授权, 保存图片
            save(data: data, toCollectionWithName: assetCollectionName)
        } else if authorizationStatus == .notDetermined {
            // 申请授权
            PHPhotoLibrary.requestAuthorization { [weak self] (status) in
                if status == .authorized {
                    // 保存图片
                    self?.save(data: data, toCollectionWithName: assetCollectionName)
                }
            }
        } else {
            showText(text: "请在设置界面, 授权访问相册")
        }
    }
    
    func save(data: Data, toCollectionWithName: String) {
        let library = PHPhotoLibrary.shared()
        library.performChanges {
            var collectionRequest: PHAssetCollectionChangeRequest?
            let assetCollection = self.getCurrentPhotoCollection(title: toCollectionWithName)
            if let ac = assetCollection {
                // 存在, 就是用当前相册创建请求
                collectionRequest = PHAssetCollectionChangeRequest(for: ac)
            } else {
                // 创建一个相册集合
                collectionRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: toCollectionWithName)
            }
            
            // 将 GIF 数据暂时保存到沙河目录
            let documentPath: String? = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
            let path = documentPath! + "gifdata"
            let result: Bool = FileManager.default.createFile(atPath: path, contents: data, attributes: nil)
            if result == true {
                // 使用文件路径的方式保存到相册
                let assetRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: URL(fileURLWithPath: path))
                let placeholder = assetRequest?.placeholderForCreatedAsset
                collectionRequest?.addAssets([placeholder] as NSFastEnumeration)
                // 清除临时数据
                do {
                    try FileManager.default.removeItem(at: URL(fileURLWithPath: path))
                } catch { print("清除临时数据失败") }
            }
        } completionHandler: { (flag, error) in
            if error == nil {
                self.showText(text: "保存成功")
            } else {
                self.showText(text: "保存失败")
            }
        }
    }
    
    func getCurrentPhotoCollection(title: String) -> PHAssetCollection? {
        // 创建搜索集合
        let result: PHFetchResult = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        // 遍历搜索集合并取出对应的相册
        var assetCollection: PHAssetCollection?
        for index in 0..<result.count {
            if result[index].localizedTitle!.contains(title) {
                assetCollection = result[index]
                break;
            }
        }
        
        return assetCollection
    }
    
}
