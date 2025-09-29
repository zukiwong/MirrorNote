// MirrorNote/ViewModels/EmotionContextViewModel.swift
import Foundation
import SwiftUI

enum ContextFieldType: String, CaseIterable {
    case place = "Location"
    case people = "People"
}

class EmotionContextViewModel: ObservableObject {
    @Published var date: Date = Date()
    @Published var place: String = ""
    @Published var people: String = ""
    
    // 沉浸式输入状态管理
    @Published var isImmersiveViewPresented: Bool = false
    @Published var currentEditingContextField: ContextFieldType? = nil
    
    // 获取对应字段的文本
    func getTextBinding(for fieldType: ContextFieldType) -> String {
        switch fieldType {
        case .place: return place
        case .people: return people
        }
    }
    
    // 设置对应字段的文本
    func setText(_ text: String, for fieldType: ContextFieldType) {
        switch fieldType {
        case .place: place = text
        case .people: people = text
        }
    }
    
    // 打开沉浸式视图
    func openImmersiveView(for fieldType: ContextFieldType) {
        currentEditingContextField = fieldType
        isImmersiveViewPresented = true
    }
    
    // 重置所有字段
    func reset() {
        date = Date()
        place = ""
        people = ""
        isImmersiveViewPresented = false
        currentEditingContextField = nil
    }
}