// usage: lift <in.png> <out.png>  — subject lift with Vision, keeps full canvas
import Vision
import AppKit
import CoreImage

let a = CommandLine.arguments
let url = URL(fileURLWithPath: a[1])
guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
      let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { fatalError("read") }
let handler = VNImageRequestHandler(cgImage: cg, options: [:])
let req = VNGenerateForegroundInstanceMaskRequest()
try handler.perform([req])
guard let obs = req.results?.first else { fatalError("no subject") }
print("instances", obs.allInstances.count)
let buf = try obs.generateMaskedImage(ofInstances: obs.allInstances, from: handler, croppedToInstancesExtent: false)
let ci = CIImage(cvPixelBuffer: buf)
let ctx = CIContext()
guard let out = ctx.createCGImage(ci, from: ci.extent) else { fatalError("render") }
let rep = NSBitmapImageRep(cgImage: out)
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[2]))
// also the soft mask on its own
let mask = try obs.generateScaledMaskForImage(forInstances: obs.allInstances, from: handler)
let mci = CIImage(cvPixelBuffer: mask)
if let mcg = ctx.createCGImage(mci, from: mci.extent) {
    try NSBitmapImageRep(cgImage: mcg).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[2].replacingOccurrences(of: ".png", with: "-mask.png")))
}
print("ok", out.width, out.height)
