// usage: svedea_edit <source.mp4> <out.mp4> <poster.jpg> <image 1> <image 2> <image 3>
//                    <screen.txt> <dog puzzle clip>
//
// Svedea's reel for the case card (896x752, 60 fps, the middle of each frame):
// the reel as it is, except
// - the phone on white that plays the dog-puzzle clip (7.13-13.25 s): its
//   screen plays the clip from its 11th second instead of its start (the dog
//   at work rather than the setting up). screen.txt has the screen's corners
//   in every frame (phone_track.swift, then phone_screen.py), and the clip
//   goes on in that perspective, inside the screen's rounded corners and
//   around the Dynamic Island
// - 28.775-34.3 s (the wind turbine and the forest, with the boat-crew photo
//   between them), which is cut, and in its place a frame of Linn's employer
//   branding work: three images that fly up into a loose, tilted collage on
//   the reel's white, hold, and fly out.
import AVFoundation
import AppKit
import CoreImage

let args = CommandLine.arguments
let srcURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])
let posterURL = URL(fileURLWithPath: args[3])
let imageURLs = args[4...6].map { URL(fileURLWithPath: $0) }
let screenURL = URL(fileURLWithPath: args[7])
let clipURL = URL(fileURLWithPath: args[8])

let W = 896, H = 752, FPS: Int32 = 60
let CUT = (from: 28.775, to: 34.3)

// MARK: reading the reel

let asset = AVURLAsset(url: srcURL)
let track = asset.tracks(withMediaType: .video).first!

func readFrames(from start: Double, to end: Double, _ body: (CVPixelBuffer, Double) -> Void) {
  let reader = try! AVAssetReader(asset: asset)
  let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
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
  drawReelImage(image)
}

func drawReelImage(_ image: CGImage) {
  let s = CGFloat(H) / CGFloat(image.height), dw = CGFloat(image.width) * s
  ctx.draw(image, in: CGRect(x: (CGFloat(W) - dw) / 2, y: 0, width: dw, height: CGFloat(H)))
}

// MARK: the toilet-roll phone's screen

let CLIP_FROM = 11.0
// as measured on the reel's front-facing frame (an iPhone 15 Pro): the
// screen's shape, its corner radius and the Dynamic Island, as shares of
// the screen's width and height
let SCREEN_ASPECT = 315.0 / 684.0
let SCREEN_RADIUS = 0.14
let ISLAND = (width: 0.305, top: 0.0175, bottom: 0.057)

// no colour management, so the reel's pixels and the clip's go through as they are
let ciContext = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
let screens: [Int: [CGPoint]] = Dictionary(uniqueKeysWithValues: try! String(contentsOf: screenURL, encoding: .utf8)
  .split(separator: "\n").filter { !$0.hasPrefix("#") }
  .map { line -> (Int, [CGPoint]) in
    let parts = line.split(separator: " ")
    let pts = parts.dropFirst().map { p -> CGPoint in
      let v = p.split(separator: ",").map { Double($0)! }
      return CGPoint(x: v[0], y: v[1])
    }
    return (Int(parts[0])!, pts)
  })
let screenFirst = screens.keys.min()!

// the clip, read forward from its 11th second as the phone needs it
let clipAsset = AVURLAsset(url: clipURL)
let clipReader = try! AVAssetReader(asset: clipAsset)
let clipOutput = AVAssetReaderTrackOutput(track: clipAsset.tracks(withMediaType: .video).first!,
                                          outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
clipReader.add(clipOutput)
clipReader.timeRange = CMTimeRange(start: CMTime(seconds: CLIP_FROM, preferredTimescale: 6000), end: clipAsset.duration)
clipReader.startReading()
var clipNow = clipOutput.copyNextSampleBuffer()!
var clipNext = clipOutput.copyNextSampleBuffer()

func clipFrame(at t: Double) -> CVPixelBuffer {
  while let next = clipNext, CMSampleBufferGetPresentationTimeStamp(next).seconds <= t + 0.0001 {
    clipNow = next
    clipNext = clipOutput.copyNextSampleBuffer()
  }
  return CMSampleBufferGetImageBuffer(clipNow)!
}

// the screen's shape in the clip's pixels: its middle, as tall as the clip
let clipSize = CVImageBufferGetDisplaySize(CMSampleBufferGetImageBuffer(clipNow)!)
let cropW = (clipSize.height * SCREEN_ASPECT).rounded(), cropX = ((clipSize.width - cropW) / 2).rounded()
/// A white shape on black, in the screen's own pixels
func localMask(_ draw: (CGContext, CGFloat, CGFloat) -> Void) -> CIImage {
  let w = Int(cropW), h = Int(clipSize.height)
  let m = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
  m.setFillColor(gray: 1, alpha: 1)
  draw(m, CGFloat(w), CGFloat(h))
  m.fillPath()
  return CIImage(cgImage: m.makeImage()!, options: [.colorSpace: NSNull()])
}
// the screen with its rounded corners
let screenMask = localMask { m, w, h in
  let r = w * SCREEN_RADIUS
  m.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil))
}
// the Dynamic Island, drawn onto the clip, so it sits where this screen
// says, rather than letting the reel's own show through
let islandMask = localMask { m, w, h in
  let iw = w * ISLAND.width, ih = h * (ISLAND.bottom - ISLAND.top)
  m.addPath(CGPath(roundedRect: CGRect(x: (w - iw) / 2, y: h * (1 - ISLAND.bottom), width: iw, height: ih),
                   cornerWidth: ih / 2, cornerHeight: ih / 2, transform: nil))
}
let black = CIImage(color: CIColor(red: 0, green: 0, blue: 0)).cropped(to: CGRect(x: 0, y: 0, width: cropW, height: clipSize.height))

/// The reel frame with the clip on the phone's screen (corners from the top left)
func drawPhone(_ buffer: CVPixelBuffer, screen: [CGPoint], clipTime: Double) {
  let base = CIImage(cvPixelBuffer: buffer, options: [.colorSpace: NSNull()])
  let reelH = base.extent.height
  let picture = CIImage(cvPixelBuffer: clipFrame(at: clipTime), options: [.colorSpace: NSNull()])
    .cropped(to: CGRect(x: cropX, y: 0, width: cropW, height: clipSize.height))
    .transformed(by: CGAffineTransform(translationX: -cropX, y: 0))
  let clip = black.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: picture, kCIInputMaskImageKey: islandMask])
  // Core Image counts from the bottom left
  let corners: [String: Any] = [
    "inputTopLeft": CIVector(x: screen[0].x, y: reelH - screen[0].y),
    "inputTopRight": CIVector(x: screen[1].x, y: reelH - screen[1].y),
    "inputBottomRight": CIVector(x: screen[2].x, y: reelH - screen[2].y),
    "inputBottomLeft": CIVector(x: screen[3].x, y: reelH - screen[3].y),
  ]
  let onScreen = clip.applyingFilter("CIPerspectiveTransform", parameters: corners)
  let mask = screenMask.applyingFilter("CIPerspectiveTransform", parameters: corners)
  let frame = onScreen.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: base, kCIInputMaskImageKey: mask])
  drawReelImage(ciContext.createCGImage(frame, from: base.extent, format: .BGRA8, colorSpace: ctx.colorSpace!)!)
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

readFrames(from: 0, to: CUT.from) { buffer, time in
  let frame = Int((time * 60).rounded())
  if let screen = screens[frame] {
    drawPhone(buffer, screen: screen, clipTime: CLIP_FROM + Double(frame - screenFirst) / 60)
  } else {
    drawReel(buffer)
  }
  emit()
}
let ebStart = written
for f in 0..<Int((LENGTH * Double(FPS)).rounded()) { drawEmployerBranding(at: Double(f) / Double(FPS)); emit() }
print("employer branding frame from", Double(ebStart) / Double(FPS), "s, for", LENGTH, "s")
readFrames(from: CUT.to, to: 36) { buffer, _ in drawReel(buffer); emit() }
print("total", Double(written) / Double(FPS), "s")

input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
if writer.status != .completed { fatalError("write failed: \(String(describing: writer.error))") }
let size = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int) ?? 0
print("\(outURL.lastPathComponent): \(size / 1024) KB")
