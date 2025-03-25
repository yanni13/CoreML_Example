//
//  ViewModel.swift
//  CoreML_Example
//
//  Created by 아우신얀 on 3/25/25.
//

import SwiftUI
import AVFoundation
import Photos
import CoreML
import Vision

class ViewModel: ObservableObject {
    @Published var scannedImages: [UIImage] = []
    @Published var showImagePicker = false
    @Published var sourceType: UIImagePickerController.SourceType = .camera
    @Published var resultText: String = "음식을 인식하세요"
    
    private var model: VNCoreMLModel!
    
    init() {
        loadModel()
    }
    
    
    // 📌 YOLOv3 모델 로드
    private func loadModel() {
        do {
            let yoloModel = try YOLOv3(configuration: MLModelConfiguration())
            model = try VNCoreMLModel(for: yoloModel.model)
        } catch {
            print("❌ 모델 로드 실패: \(error.localizedDescription)")
        }
    }
    
    // 📌 이미지 분석 실행
    func analyzeImage(_ image: UIImage) {
        guard let model = model else { return }
        guard let ciImage = CIImage(image: image) else { return }

        let request = VNCoreMLRequest(model: model) { request, error in
            self.processResults(request.results)
        }

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("❌ 이미지 분석 실패: \(error.localizedDescription)")
            }
        }
    }

    // 📌 분석 결과 처리
    private func processResults(_ results: [Any]?) {
        guard let results = results as? [VNRecognizedObjectObservation] else {
            DispatchQueue.main.async {
                self.resultText = "음식을 인식하지 못했습니다."
            }
            print("❌ 결과 처리 실패: 결과가 VNRecognizedObjectObservation 형식이 아닙니다.")
            return
        }

        // FoodData 가져오기
        let detectedItems = results
            .flatMap { $0.labels }
            .sorted { $0.confidence > $1.confidence }
//            .prefix(1)
            .prefix(3) // 상위 3개 결과만 표시
//
//        var resultTextArray: [String] = []
//        for label in detectedItems {
//            let calorie = FoodData.calorieMapping[label.identifier] ?? 0
//            resultTextArray.append("\(label.identifier) (\(String(format: "%.2f", label.confidence * 100))%) - \(calorie) kcal")
//        }
//
//        DispatchQueue.main.async {
//            self.resultText = resultTextArray.isEmpty ? "사진이 없기 때문에 음식을 인식하지 못했습니다." : resultTextArray.joined(separator: ", ")
//        }
        
        if detectedItems.isEmpty {
            DispatchQueue.main.async {
                self.resultText = "음식을 인식하지 못했습니다."
            }
            print("❌ 결과 처리 실패: 인식된 항목이 없습니다.")
        } else {
            var resultTextArray: [String] = []
            for label in detectedItems {
                let calorie = FoodData.calorieMapping[label.identifier] ?? 0
                resultTextArray.append("\(label.identifier) (\(String(format: "%.2f", label.confidence * 100))%) - \(calorie) kcal")
                print("✅ 인식된 항목: \(label.identifier), 신뢰도: \(label.confidence), 칼로리: \(calorie)")
            }

            DispatchQueue.main.async {
                self.resultText = resultTextArray.joined(separator: "\n")
            }
        }
    }
    
    
    // 앨범 접근 권한
    func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        handlePhotoLibraryStatus(status)
    }
    
    func handlePhotoLibraryStatus(_ status: PHAuthorizationStatus) {
            switch status {
            case .authorized, .limited:
                sourceType = .photoLibrary
                showImagePicker = true
            case .denied, .restricted:
                showAlertAuth(type: "앨범")
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                    DispatchQueue.main.async {
                        self.handlePhotoLibraryStatus(status)
                    }
                }
            @unknown default:
                break
            }
        }
    
    // 카메라 접근 권한
    func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            sourceType = .camera
        case .denied, .restricted:
            showAlertAuth(type: "카메라")
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.sourceType = .camera
                    }
                }
            }
        @unknown default:
            break
        }
    }
    // 설정창으로 이동하는 팝업창
    private func showAlertAuth(type: String) {
        let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "이 앱"
        let alertVC = UIAlertController(
            title: "설정",
            message: "\(appName)이(가) \(type) 접근 허용되어 있지 않습니다. 설정화면으로 가시겠습니까?",
            preferredStyle: .alert
        )
        let cancelAction = UIAlertAction(title: "취소", style: .cancel, handler: nil)
        let confirmAction = UIAlertAction(title: "확인", style: .default) { _ in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
        }
        alertVC.addAction(cancelAction)
        alertVC.addAction(confirmAction)
        
        UIApplication.shared.windows.first?.rootViewController?.present(alertVC, animated: true)
    }
}
