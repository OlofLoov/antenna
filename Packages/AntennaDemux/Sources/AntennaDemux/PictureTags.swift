import CoreVideo
import FFmpeg
import Foundation

/// The pixel shape and color attachments of pictures the FFmpeg path makes
/// itself, so the renderer shows them at their shape and in their colors
/// (playback-engine/pictures-show-at-their-shape-and-in-their-colors).
enum PictureTags {
    /// Sets the pixel aspect ratio and the colors FFmpeg read for `frame`,
    /// then SD or HD colors for whatever the stream left unnamed.
    static func apply(from frame: UnsafePointer<AVFrame>, to pixels: CVPixelBuffer) {
        let shape = frame.pointee.sample_aspect_ratio
        if shape.num > 0, shape.den > 0, shape.num != shape.den {
            let spacing: [CFString: Int] = [
                kCVImageBufferPixelAspectRatioHorizontalSpacingKey: Int(shape.num),
                kCVImageBufferPixelAspectRatioVerticalSpacingKey: Int(shape.den),
            ]
            CVBufferSetAttachment(pixels, kCVImageBufferPixelAspectRatioKey, spacing as CFDictionary, .shouldPropagate)
        }
        let named: [(CFString, Unmanaged<CFString>?)] = [
            (kCVImageBufferYCbCrMatrixKey, CVYCbCrMatrixGetStringForIntegerCodePoint(Int32(frame.pointee.colorspace.rawValue))),
            (kCVImageBufferColorPrimariesKey, CVColorPrimariesGetStringForIntegerCodePoint(Int32(frame.pointee.color_primaries.rawValue))),
            (kCVImageBufferTransferFunctionKey, CVTransferFunctionGetStringForIntegerCodePoint(Int32(frame.pointee.color_trc.rawValue))),
        ]
        for (key, value) in named {
            if let value { CVBufferSetAttachment(pixels, key, value.takeUnretainedValue(), .shouldPropagate) }
        }
        fillMissingColors(pixels)
    }

    /// Names the colors of a picture that has no YCbCr matrix: BT.601 for SD
    /// (up to 576 lines), with EBU primaries at 576 lines and SMPTE C below,
    /// and BT.709 for anything larger. Broadcast SD that says nothing is in
    /// SD colors. A picture with a matrix keeps the colors it has.
    static func fillMissingColors(_ pixels: CVPixelBuffer) {
        guard CVBufferCopyAttachment(pixels, kCVImageBufferYCbCrMatrixKey, nil) == nil else { return }
        let height = CVPixelBufferGetHeight(pixels)
        let isSD = height <= 576
        let matrix = isSD ? kCVImageBufferYCbCrMatrix_ITU_R_601_4 : kCVImageBufferYCbCrMatrix_ITU_R_709_2
        let primaries =
            isSD
            ? (height > 480 ? kCVImageBufferColorPrimaries_EBU_3213 : kCVImageBufferColorPrimaries_SMPTE_C)
            : kCVImageBufferColorPrimaries_ITU_R_709_2
        CVBufferSetAttachment(pixels, kCVImageBufferYCbCrMatrixKey, matrix, .shouldPropagate)
        if CVBufferCopyAttachment(pixels, kCVImageBufferColorPrimariesKey, nil) == nil {
            CVBufferSetAttachment(pixels, kCVImageBufferColorPrimariesKey, primaries, .shouldPropagate)
        }
        if CVBufferCopyAttachment(pixels, kCVImageBufferTransferFunctionKey, nil) == nil {
            CVBufferSetAttachment(pixels, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
        }
    }
}
