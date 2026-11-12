import AntennaCore
import Foundation

extension DemuxEngine {
    public func stop() async {
        hold.clear()
        await shutDown()
    }

    /// Stops for Apple's player to take over. The last picture stays on
    /// screen in this engine's layer until `hold` is cleared by that
    /// engine's first frame, unless this engine has started again by then.
    public func handOver() async {
        guard state != .idle, !videoLayer.isHidden else { return await shutDown() }
        await shutDown(keepingPicture: true)
        let held = generation
        hold.keep { [weak self] in
            guard let self, self.generation == held else { return }
            self.videoLayer.isHidden = true
            Task { await self.videoLayer.sampleBufferRenderer.flush(removingDisplayedImage: true) }
        }
    }

    private func shutDown(keepingPicture: Bool = false) async {
        generation += 1
        wantsPlay = false
        request = nil
        openAhead([])
        close()
        retireTimeshift()
        display.letGo()
        set(.idle)
        guard !keepingPicture else { return }
        videoLayer.isHidden = true
        await videoLayer.sampleBufferRenderer.flush(removingDisplayedImage: true)
    }
}
