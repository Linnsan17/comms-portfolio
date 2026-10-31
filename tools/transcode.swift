// usage: transcode <in> <out.mp4> <poster.jpg> <width> <height> <bitrate>
// Video only (audio dropped), H.264 High, moov atom first for streaming.
import AVFoundation
import AppKit

let a = CommandLine.arguments
let input = URL(fileURLWithPath: a[1]), output = URL(fileURLWithPath: a[2]), poster = URL(fileURLWithPath: a[3])
let width = Int(a[4])!, height = Int(a[5])!, bitrate = Int(a[6])!
try? FileManager.default.removeItem(at: output)

let asset = AVURLAsset(url: input)
guard let track = asset.tracks(withMediaType: .video).first else { fatalError("no video track") }
let reader = try! AVAssetReader(asset: asset)
let readerOut = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
reader.add(readerOut)

let writer = try! AVAssetWriter(outputURL: output, fileType: .mp4)
writer.shouldOptimizeForNetworkUse = true
let settings: [String: Any] = [
  AVVideoCodecKey: AVVideoCodecType.h264,
  AVVideoWidthKey: width,
  AVVideoHeightKey: height,
  AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
  AVVideoCompressionPropertiesKey: [
    AVVideoAverageBitRateKey: bitrate,
    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
    AVVideoMaxKeyFrameIntervalKey: 60,
  ],
]
let writerIn = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
writerIn.expectsMediaDataInRealTime = false
writer.add(writerIn)

reader.startReading()
writer.startWriting()
writer.startSession(atSourceTime: .zero)
let queue = DispatchQueue(label: "transcode")
let done = DispatchSemaphore(value: 0)
writerIn.requestMediaDataWhenReady(on: queue) {
  while writerIn.isReadyForMoreMediaData {
    if let buffer = readerOut.copyNextSampleBuffer() {
      writerIn.append(buffer)
    } else {
      writerIn.markAsFinished()
      writer.finishWriting { done.signal() }
      return
    }
  }
}
done.wait()
if writer.status != .completed { fatalError("write failed: \(String(describing: writer.error))") }

// Poster: a frame half a second in, at the output size
let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.maximumSize = CGSize(width: width, height: height)
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero
let cg = try! gen.copyCGImage(at: CMTime(seconds: 0.5, preferredTimescale: 600), actualTime: nil)
let rep = NSBitmapImageRep(cgImage: cg)
try! rep.representation(using: .jpeg, properties: [.compressionFactor: 0.72])!.write(to: poster)
let size = (try? FileManager.default.attributesOfItem(atPath: output.path)[.size] as? Int) ?? 0
print("\(output.lastPathComponent): \(size / 1024) KB")
