## 1. Let go of bytes and objects live playback is done with

- [x] 1.1 Read each part of the local buffer in an autorelease pool of its own in `DiskTimeshiftFiles.read`
- [x] 1.2 Keep the bytes received in `HTTPByteStream` from a read position, and clear the taken ones once they are half the storage, instead of `Data.removeFirst`
- [x] 1.3 Read and handle each packet of a run in an autorelease pool of its own in `DemuxRun.pump`
- [x] 1.4 `DiskTimeshiftFilesTests`: 300 reads of 1 MB on a thread of their own leave the footprint within 32 MB
- [x] 1.5 `DemuxMemoryTests`: 200 MB through a connection, taken or kept as a stream opened ahead, leaves malloc within 16 MB
- [x] 1.6 `DemuxMemoryTests`: 5,000 deinterlaced pictures of 576i and 1080i live TV leave malloc within 256 bytes a picture

## 2. Verify

- [x] 2.1 Each scenario has a test citing `playback-engine/live-playback-keeps-memory-steady`
- [x] 2.2 `/opsx:verify` passes
