// usage: nilar_edit <nilar reel.mp4> <almedalen film.mp4> <out.mp4> <poster.jpg>
//
// Nilar's reel for the case card (896x752, 30 fps, the middle of each frame):
// the reel as it is (the website on a monitor, then on a phone, then the
// photos from the factory), then the last 20.9 s of Nilar's Almedalen film,
// from the cut at 43.96 s (power lines, a charging station, the city, a bike,
// a car, and the Nilar logo to end on), and back to the start.
//
// The reel is 30 fps stored twice over at 60, so every other frame is kept;
// the Almedalen film is 25 fps, each output frame shows the one due then.
// Pixels go through as they are and the film is tagged BT.709 like its
// sources, so the colours match them.
import AVFoundation
import AppKit

let args = CommandLine.arguments
let reelURL = URL(fileURLWithPath: args[1])
let filmURL = URL(fileURLWithPath: args[2])
let outURL = URL(fileURLWithPath: args[3])
let posterURL = URL(fileURLWithPath: args[4])

let W = 896, H = 752, FPS: Int32 = 30
let ALMEDALEN = (from: 43.96, to: 64.88)

// MARK: reading

/// Every frame of a film between two times, with its time
func readFrames(_ url: URL, from start: Double, to end: Double, _ body: (CVPixelBuffer, Double) -> Void) {
  let asset = AVURLAsset(url: url)
  let reader = try! AVAssetReader(asset: asset)
  let output = AVAssetReaderTrackOutput(track: asset.tracks(withMediaType: .video).first!,
                                        outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
  output.alwaysCopiesSampleData = false
  reader.add(output)
  reader.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 6000), end: CMTime(seconds: end, preferredTimescale: 6000))
  reader.startReading()
  while let sample = output.copyNextSampleBuffer() {
    guard let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
    body(buffer, CMSampleBufferGetPresentationTimeStamp(sample).seconds)
  }
}

// MARK: the frame we draw into

let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
ctx.interpolationQuality = .high

/// The middle of a frame, cropped to the card's shape, its pixels as they are
func draw(_ buffer: CVPixelBuffer) {
  CVPixelBufferLockBaseAddress(buffer, .readOnly)
  defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
  let bpr = CVPixelBufferGetBytesPerRow(buffer), bh = CVPixelBufferGetHeight(buffer)
  let bytes = Data(bytes: CVPixelBufferGetBaseAddress(buffer)!, count: bpr * bh)
  let image = CGImage(width: CVPixelBufferGetWidth(buffer), height: bh, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bpr,
                      space: ctx.colorSpace!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                      provider: CGDataProvider(data: bytes as CFData)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
  let s = CGFloat(H) / CGFloat(image.height), dw = CGFloat(image.width) * s
  ctx.draw(image, in: CGRect(x: (CGFloat(W) - dw) / 2, y: 0, width: dw, height: CGFloat(H)))
}

// MARK: writing

try? FileManager.default.removeItem(at: outURL)
let writer = try! AVAssetWriter(outputURL: outURL, fileType: .mp4)
writer.shouldOptimizeForNetworkUse = true
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
  AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
  AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 2_000_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel, AVVideoMaxKeyFrameIntervalKey: 30],
  AVVideoColorPropertiesKey: [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2, AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2, AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2],
])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
  kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H,
])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)
var written = 0
let data = ctx.data!.bindMemory(to: UInt8.self, capacity: ctx.bytesPerRow * H)

func emit() {
  while !input.isReadyForMoreMediaData { usleep(2000) }
  var pb: CVPixelBuffer?
  CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
  CVPixelBufferLockBaseAddress(pb!, [])
  let dst = CVPixelBufferGetBaseAddress(pb!)!.assumingMemoryBound(to: UInt8.self)
  let dbpr = CVPixelBufferGetBytesPerRow(pb!)
  for y in 0..<H { memcpy(dst + y * dbpr, data + y * ctx.bytesPerRow, W * 4) }
  CVPixelBufferUnlockBaseAddress(pb!, [])
  // already BT.709, so the encoder leaves it as it is
  CVBufferSetAttachment(pb!, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
  CVBufferSetAttachment(pb!, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
  CVBufferSetAttachment(pb!, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)
  adaptor.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(written), timescale: FPS))
  if written == Int(FPS) / 2 { // the poster: half a second in
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .jpeg, properties: [.compressionFactor: 0.72])!.write(to: posterURL)
  }
  written += 1
}

// the reel, every other frame
var seen = 0
readFrames(reelURL, from: 0, to: 10_000) { buffer, _ in
  if seen % 2 == 0 { draw(buffer); emit() }
  seen += 1
}
let filmStart = written
// the Almedalen film: each output frame shows the film's latest frame by its
// time, so once a newer film frame turns up, the output frames before it get
// the one before
let frames = Int(((ALMEDALEN.to - ALMEDALEN.from) * Double(FPS)).rounded(.down))
var shown = 0
var current: CVPixelBuffer? = nil
readFrames(filmURL, from: ALMEDALEN.from, to: ALMEDALEN.to) { buffer, time in
  let shownTime = { ALMEDALEN.from + Double(shown) / Double(FPS) }
  while shown < frames, let earlier = current ?? Optional(buffer), shownTime() < time - 0.0001 {
    draw(earlier)
    emit()
    shown += 1
  }
  current = buffer
}
if let last = current { while shown < frames { draw(last); emit(); shown += 1 } }
print("reel", Double(filmStart) / Double(FPS), "s, then Almedalen", Double(written - filmStart) / Double(FPS), "s; total", Double(written) / Double(FPS), "s")

input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
if writer.status != .completed { fatalError("write failed: \(String(describing: writer.error))") }
let size = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int) ?? 0
print("\(outURL.lastPathComponent): \(size / 1024) KB")
