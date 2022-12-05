// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import Foundation
import AudioUnit
import AVFoundation

/// Voice struct used by the audio thread.
struct SamplerVoice {

    // Is the voice in use?
    var inUse: Bool = false

    // Sample data we're playing
    var data: UnsafeMutableAudioBufferListPointer?

    // Current sample we're playing
    var playhead: Int = 0

    // Envelope state, etc. would go here.
}

/// Renders contents of a file
class SamplerAudioUnit: AUAudioUnit {

    private var inputBusArray: AUAudioUnitBusArray!
    private var outputBusArray: AUAudioUnitBusArray!

    let inputChannelCount: NSNumber = 2
    let outputChannelCount: NSNumber = 2

    var floatChannelDatas: [FloatChannelData] = []
    var files: [AVAudioFile] = [] {
        didSet {
            floatChannelDatas.removeAll()
            for file in files {
                if let data = file.toFloatChannelData() {
                    floatChannelDatas.append(data)
                }
            }
        }
    }

    /// Associate a midi note with a sample.
    func setSample(_ sample: AVAudioPCMBuffer, midiNote: Int8) {

    }

    /// Play a sample immediately.
    func playSample(_ sample: AVAudioPCMBuffer) {

    }

    /// A potential sample for every MIDI note.
    private var samples = [AVAudioPCMBuffer?](repeating: nil, count: 128)

    /// Voices for playing back samples.
    private var voices = [SamplerVoice](repeating: SamplerVoice(), count: 1024)

    override public var channelCapabilities: [NSNumber]? {
        return [inputChannelCount, outputChannelCount]
    }

    /// Initialize with component description and options
    /// - Parameters:
    ///   - componentDescription: Audio Component Description
    ///   - options: Audio Component Instantiation Options
    /// - Throws: error
    override public init(componentDescription: AudioComponentDescription,
                         options: AudioComponentInstantiationOptions = []) throws {

        try super.init(componentDescription: componentDescription, options: options)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        inputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [])
        outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [try AUAudioUnitBus(format: format)])

        parameterTree = AUParameterTree.createTree(withChildren: [])
    }

    override var inputBusses: AUAudioUnitBusArray {
        inputBusArray
    }

    override var outputBusses: AUAudioUnitBusArray {
        outputBusArray
    }

    override func allocateRenderResources() throws {

    }

    override func deallocateRenderResources() {

    }

    var playheadInSamples: Int = 0
    var isPlaying: Bool = false

    override var internalRenderBlock: AUInternalRenderBlock {
        { (actionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
           timeStamp: UnsafePointer<AudioTimeStamp>,
           frameCount: AUAudioFrameCount,
           outputBusNumber: Int,
           outputBufferList: UnsafeMutablePointer<AudioBufferList>,
           renderEvents: UnsafePointer<AURenderEvent>?,
           inputBlock: AURenderPullInputBlock?) in

            let ablPointer = UnsafeMutableAudioBufferListPointer(outputBufferList)

            for frame in 0 ..< Int(frameCount) {
                var value: Float = 0.0
                let sample = self.playheadInSamples + frame
                if sample < self.floatChannelDatas[0][0].count {
                    value = self.floatChannelDatas[0][0][sample]
                }
                for buffer in ablPointer {
                    let buf = UnsafeMutableBufferPointer<Float>(buffer)
                    assert(frame < buf.count)
                    buf[frame] = self.isPlaying ? value : 0.0
                }
            }
            if self.isPlaying {
                self.playheadInSamples += Int(frameCount)
            }

            return noErr
        }
    }

}

class Sampler: Node {
    let connections: [Node] = []

    let avAudioNode: AVAudioNode
    let samplerAU: SamplerAudioUnit

    /// Position of playback in seconds
    var playheadPosition: Double = 0.0

    func movePlayhead(to position: Double) {
        samplerAU.playheadInSamples = Int(position * 44100)
    }

    func rewind() {
        movePlayhead(to: 0)
    }

    func play() {
        samplerAU.isPlaying = true
    }

    func stop() {
        samplerAU.isPlaying = false
    }


    init(file: AVAudioFile) {

        let componentDescription = AudioComponentDescription(generator: "tpla")

        AUAudioUnit.registerSubclass(SamplerAudioUnit.self,
                                     as: componentDescription,
                                     name: "Player AU",
                                     version: .max)
        avAudioNode = instantiate(componentDescription: componentDescription)
        samplerAU = avAudioNode.auAudioUnit as! SamplerAudioUnit
        samplerAU.files.append(file)
    }
}
