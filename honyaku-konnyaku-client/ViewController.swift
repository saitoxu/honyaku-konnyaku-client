import UIKit
import Alamofire
import Speech

class ViewController: UIViewController {

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var startBtn: UIButton!
    @IBOutlet weak var translateBtn: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        speechRecognizer.delegate = self
        startBtn.isEnabled = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        requestRecognizerAuthorization()
    }

    @IBAction func start(_ sender: Any) {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            startBtn.isEnabled = false
            startBtn.setTitle("Stopping", for: .disabled)
        } else {
            try! startRecording()
            startBtn.setTitle("Clear", for: [])
        }
    }

    @IBAction func translate(_ sender: Any) {
        let text = self.label.text
        print(text!)

        if !(text?.isEmpty)! {
            Alamofire.request("http://example.com")
                .responseString { response in
                    // print("Response String: \(response.result.value)")
                    print("response")
            }
        }
    }

    private func requestRecognizerAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation { [weak self] in
                guard let `self` = self else { return }

                switch authStatus {
                case .authorized:
                    self.startBtn.isEnabled = true

                case .denied:
                    self.startBtn.isEnabled = false
                    self.startBtn.setTitle("Access denied", for: .disabled)

                case .restricted:
                    self.startBtn.isEnabled = false
                    self.startBtn.setTitle("Access restricted", for: .disabled)

                case .notDetermined:
                    self.startBtn.isEnabled = false
                    self.startBtn.setTitle("No permission", for: .disabled)
                }
            }
        }
    }

    private func startRecording() throws {
        refreshTask()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let inputNode = audioEngine.inputNode else { fatalError("Audio engine has no input node") }
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }

        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let `self` = self else { return }

            var isFinal = false

            if let result = result {
                self.label.text = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }

            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil

                self.startBtn.isEnabled = true
                self.startBtn.setTitle("Start", for: [])
                self.label.text = ""
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }

        try startAudioEngine()
    }

    private func refreshTask() {
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
    }
    
    private func startAudioEngine() throws {
        audioEngine.prepare()
        try audioEngine.start()
    }
}

extension ViewController: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            startBtn.isEnabled = true
            startBtn.setTitle("Start", for: [])
        } else {
            startBtn.isEnabled = false
            startBtn.setTitle("Clear", for: .disabled)
        }
    }
}
