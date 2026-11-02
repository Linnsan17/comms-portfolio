// usage: svedea_edit <source.mp4> <out.mp4> <poster.jpg> <image 1> <image 2> <image 3>
//
// Svedea's reel for the case card (896x752, 60 fps, the middle of each frame):
// the reel as it is, without 28.75-34.3 s (the wind turbine and the forest,
// with the boat-crew photo between them), and in their place a frame of
// Linn's employer branding work: three images that fly up into a loose,
// tilted collage on the reel's white, hold, and fly out.
import AVFoundation
import AppKit

let args = CommandLine.arguments
let srcURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])
let posterURL = URL(fileURLWithPath: args[3])
let imageURLs = args[4...6].map { URL(fileURLWithPath: $0) }

let W = 896, H = 752, FPS: Int32 = 60
let CUT = (from: 28.775, to: 34.3)

// MARK: reading the reel

let asset = AVURLAsset(url: srcURL)
let track = asset.tracks(withMediaType: .video).first!

func readFrames(from start: Double, to end: Double, _ body: (CVPixelBuffer) -> Void) {
  let reader = try! AVAssetReader(asset: asset)
  let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
  output.alwaysCopiesSampleData = false
  reader.add(output)
  reader.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 6000), end: CMTime(seconds: end, preferredTimescale: 6000))
  reader.startReading()
  while let sample = output.copyNextSampleBuffer() {
    guard let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
    body(buffer)
  }
}

// MARK: the frame we draw into

let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
ctx.interpolationQuality = .high

/// The middle of a reel frame, cropped to the card's shape. Its pixels go in
/// as they are, with no colour conversion, and the output is tagged with the
/// reel's own colour (BT.709), so it keeps the reel's colours exactly.
func drawReel(_ buffer: CVPixelBuffer) {
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

// MARK: the employer branding frame

let images = imageURLs.map { NSImage(contentsOf: $0)!.cgImage(forProposedRect: nil, context: nil, hints: nil)! }
// where each image settles (centre from the top left, height, tilt in degrees),
// left to right, each drawn over the one before
let places: [(x: CGFloat, y: CGFloat, h: CGFloat, tilt: CGFloat)] = [
  (180, 384, 380, -4), (462, 366, 400, 3), (730, 388, 440, -3),
]
let IN = 0.7, OUT = 0.55, STAGGER = 0.14, HOLD_UNTIL = 2.95
let LENGTH = HOLD_UNTIL + STAGGER * 2 + OUT + 0.15

func easeOut(_ t: Double) -> Double { 1 - pow(1 - min(max(t, 0), 1), 3) }
func easeIn(_ t: Double) -> Double { pow(min(max(t, 0), 1), 3) }

func drawEmployerBranding(at t: Double) {
  ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
  ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
  for (i, (image, place)) in zip(images, places).enumerated() {
    let start = STAGGER * Double(i), leave = HOLD_UNTIL + STAGGER * Double(i)
    // up from below the frame, and out over the top
    let enter = easeOut((t - start) / IN), exit = easeIn((t - leave) / OUT)
    if enter <= 0 || exit >= 1 { continue }
    let dy = (1 - enter) * 720 - exit * 760
    let tilt = place.tilt + CGFloat((1 - enter) * 9 - exit * 7)
    let h = place.h, w = h * CGFloat(image.width) / CGFloat(image.height)
    ctx.saveGState()
    ctx.translateBy(x: place.x, y: CGFloat(H) - (place.y + CGFloat(dy)))
    ctx.rotate(by: -tilt * .pi / 180)
    ctx.draw(image, in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
    ctx.restoreGState()
  }
}

// MARK: writing

try? FileManager.default.removeItem(at: outURL)
let writer = try! AVAssetWriter(outputURL: outURL, fileType: .mp4)
writer.shouldOptimizeForNetworkUse = true
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
  AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
  AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 2_000_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel, AVVideoMaxKeyFrameIntervalKey: 60],
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
  // already the reel's BT.709 colour, so the encoder leaves it as it is
  CVBufferSetAttachment(pb!, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
  CVBufferSetAttachment(pb!, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
  CVBufferSetAttachment(pb!, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)
  adaptor.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(written), timescale: FPS))
  if written == Int(FPS) / 2 { // the poster: half a second in
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])!.write(to: posterURL)
  }
  written += 1
}

readFrames(from: 0, to: CUT.from) { drawReel($0); emit() }
let ebStart = written
for f in 0..<Int((LENGTH * Double(FPS)).rounded()) { drawEmployerBranding(at: Double(f) / Double(FPS)); emit() }
print("employer branding frame from", Double(ebStart) / Double(FPS), "s, for", LENGTH, "s")
readFrames(from: CUT.to, to: 36) { drawReel($0); emit() }
print("total", Double(written) / Double(FPS), "s")

input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
if writer.status != .completed { fatalError("write failed: \(String(describing: writer.error))") }
let size = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int) ?? 0
print("\(outURL.lastPathComponent): \(size / 1024) KB")
