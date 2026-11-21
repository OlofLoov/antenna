import AntennaCore
import AntennaTestSupport
import CoreMedia
import CoreVideo
import Foundation
import Testing

@testable import AntennaDemux

/// Widescreen SD reaches the renderer with its pixel shape and SD colors
/// (playback-engine/pictures-show-at-their-shape-and-in-their-colors).
@Suite(.serialized, .timeLimit(.minutes(1))) struct DemuxPictureShapeTests {
    @Test(
        "playback-engine/pictures-show-at-their-shape-and-in-their-colors a 16:9 SD picture reaches the renderer 64:45 wide in SD colors",
        arguments: ["anamorphic-576.ts", "anamorphic-576i.ts"])
    func widescreenSD(file: String) async throws {
        let outcome = try await PictureCheck.run(FixtureServer.fixtures().appending(path: file))
        let images = outcome.buffers.compactMap(CMSampleBufferGetImageBuffer)
        try #require(images.count >= 10)
        for image in images {
            #expect(CVPixelBufferGetWidth(image) == 720 && CVPixelBufferGetHeight(image) == 576)
            let shape = CVBufferCopyAttachment(image, kCVImageBufferPixelAspectRatioKey, nil) as? [String: Int]
            #expect(shape?[kCVImageBufferPixelAspectRatioHorizontalSpacingKey as String] == 64)
            #expect(shape?[kCVImageBufferPixelAspectRatioVerticalSpacingKey as String] == 45)
            let matrix = CVBufferCopyAttachment(image, kCVImageBufferYCbCrMatrixKey, nil) as? String
            #expect(matrix == kCVImageBufferYCbCrMatrix_ITU_R_601_4 as String)
            let fields = CVBufferCopyAttachment(image, kCVImageBufferFieldCountKey, nil) as? Int
            #expect(fields == nil || fields == 1)
        }
        let format = try #require(outcome.buffers.first.flatMap(CMSampleBufferGetFormatDescription))
        let extensionShape = CMFormatDescriptionGetExtension(format, extensionKey: kCMFormatDescriptionExtension_PixelAspectRatio)
        #expect((extensionShape as? [String: Int])?[kCMFormatDescriptionKey_PixelAspectRatioHorizontalSpacing as String] == 64)
    }

    @Test("playback-engine/pictures-show-at-their-shape-and-in-their-colors SD with no color tags is tagged BT.601 and HD BT.709")
    func untaggedColors() throws {
        let sd = try #require(makePixels(width: 720, height: 576))
        PictureTags.fillMissingColors(sd)
        #expect(CVBufferCopyAttachment(sd, kCVImageBufferYCbCrMatrixKey, nil) as? String == kCVImageBufferYCbCrMatrix_ITU_R_601_4 as String)
        #expect(
            CVBufferCopyAttachment(sd, kCVImageBufferColorPrimariesKey, nil) as? String == kCVImageBufferColorPrimaries_EBU_3213 as String)
        let ntsc = try #require(makePixels(width: 720, height: 480))
        PictureTags.fillMissingColors(ntsc)
        #expect(
            CVBufferCopyAttachment(ntsc, kCVImageBufferColorPrimariesKey, nil) as? String == kCVImageBufferColorPrimaries_SMPTE_C as String)
        let hd = try #require(makePixels(width: 1920, height: 1080))
        PictureTags.fillMissingColors(hd)
        #expect(CVBufferCopyAttachment(hd, kCVImageBufferYCbCrMatrixKey, nil) as? String == kCVImageBufferYCbCrMatrix_ITU_R_709_2 as String)
        let tagged = try #require(makePixels(width: 720, height: 576))
        CVBufferSetAttachment(tagged, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)
        PictureTags.fillMissingColors(tagged)
        #expect(
            CVBufferCopyAttachment(tagged, kCVImageBufferYCbCrMatrixKey, nil) as? String == kCVImageBufferYCbCrMatrix_ITU_R_709_2 as String)
    }

    private func makePixels(width: Int, height: Int) -> CVPixelBuffer? {
        var pixels: CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, nil, &pixels)
        return pixels
    }
}
