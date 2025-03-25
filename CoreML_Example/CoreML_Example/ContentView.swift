//
//  ContentView.swift
//  CoreML_Example
//
//  Created by 아우신얀 on 3/25/25.
//

import SwiftUI
import Vision
import CoreML

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var isActive = false
    @ObservedObject var viewModel = ViewModel()
    
    
    var body: some View {
        VStack(spacing: 20) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
            
            // 분석 결과 테스트
            Text(viewModel.resultText)
                .font(.title)
                .padding()
            
            
            
            // 사진 촬영
            Button(action: {
                viewModel.checkCameraPermission()
                isActive = true
            }, label: {
                Text("사진 촬영하기")
            })
            
            
            // 앨범에서 사진 가져오기
            Button(action: {
                viewModel.checkPhotoLibraryPermission()
                isActive = true
            }, label: {
                Text("앨범에서 사진 가져오기")
            })
            
        }
        .padding()
        .sheet(isPresented: $viewModel.showImagePicker) {
            ImagePicker(image: $selectedImage, isActive: $isActive, sourceType: viewModel.sourceType)
                .onDisappear {
                    if let image = selectedImage {
                        viewModel.analyzeImage(image) // 이미지 분석 실행
                    }
                }
        }
    }
}

#Preview {
    ContentView()
}
