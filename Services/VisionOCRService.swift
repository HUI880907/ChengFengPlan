// MARK: - Imports
import Foundation
import Vision
import UIKit

// MARK: - VisionOCRService

/// OCR 文字识别服务，基于 Apple Vision 框架
final class VisionOCRService {

    // MARK: - Shared Instance

    static let shared = VisionOCRService()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 从图片中识别文字
    /// - Parameter image: 输入图片
    /// - Returns: 识别到的完整文字
    func recognizeText(from image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en"]

        do {
            try requestHandler.perform([request])
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return ""
            }

            let text = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")

            return text
        } catch {
            print("[VisionOCRService] OCR error: \(error.localizedDescription)")
            return ""
        }
    }

    /// 从图片中识别文字并返回置信度信息
    /// - Parameter image: 输入图片
    /// - Returns: 文字和置信度元组数组
    func recognizeTextWithConfidence(from image: UIImage) async -> [(text: String, confidence: Float)] {
        guard let cgImage = image.cgImage else { return [] }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en"]

        do {
            try requestHandler.perform([request])
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return []
            }

            var results: [(text: String, confidence: Float)] = []

            for observation in observations {
                if let candidate = observation.topCandidates(1).first {
                    let confidence = candidate.confidence
                    results.append((text: candidate.string, confidence: confidence))
                }
            }

            return results
        } catch {
            print("[VisionOCRService] OCR error: \(error.localizedDescription)")
            return []
        }
    }

    /// 从图片中识别文字并返回原始观察结果
    /// - Parameter image: 输入图片
    /// - Returns: VNRecognizedTextObservation 数组
    func recognizeTextObservations(from image: UIImage) async -> [VNRecognizedTextObservation] {
        guard let cgImage = image.cgImage else { return [] }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en"]

        do {
            try requestHandler.perform([request])
            return request.results as? [VNRecognizedTextObservation] ?? []
        } catch {
            print("[VisionOCRService] OCR error: \(error.localizedDescription)")
            return []
        }
    }

    /// 快速识别（牺牲精度换取速度）
    func recognizeTextFast(from image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["zh-Hans", "en"]

        do {
            try requestHandler.perform([request])
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return ""
            }

            return observations.compactMap {
                $0.topCandidates(1).first?.string
            }.joined(separator: "\n")
        } catch {
            print("[VisionOCRService] Fast OCR error: \(error.localizedDescription)")
            return ""
        }
    }
}
