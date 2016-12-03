//
//  ViewController.swift
//  honyaku-konnyaku-client
//
//  Created by Yosuke SAITO on 2016/11/19.
//  Copyright © 2016年 saitoxu. All rights reserved.
//

import UIKit
import Alamofire
import Speech

class ViewController: UIViewController {

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var button: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        speechRecognizer.delegate = self
        button.isEnabled = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        requestRecognizerAuthorization()
    }

    @IBAction func tappedStartButton(_ sender: Any) {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            button.isEnabled = false
            button.setTitle("停止中", for: .disabled)
            Alamofire.request("http://example.com")
                .responseString { response in
                    print("Response String: \(response.result.value)")
                }
        } else {
            try! startRecording()
            button.setTitle("音声認識を中止", for: [])
        }
    }

    private func requestRecognizerAuthorization() {
        // 認証処理
        SFSpeechRecognizer.requestAuthorization { authStatus in
            // メインスレッドで処理したい内容のため、OperationQueue.main.addOperationを使う
            OperationQueue.main.addOperation { [weak self] in
                guard let `self` = self else { return }

                switch authStatus {
                case .authorized:
                    self.button.isEnabled = true

                case .denied:
                    self.button.isEnabled = false
                    self.button.setTitle("音声認識へのアクセスが拒否されています。", for: .disabled)

                case .restricted:
                    self.button.isEnabled = false
                    self.button.setTitle("この端末で音声認識はできません。", for: .disabled)

                case .notDetermined:
                    self.button.isEnabled = false
                    self.button.setTitle("音声認識はまだ許可されていません。", for: .disabled)
                }
            }
        }
    }

    private func startRecording() throws {
        refreshTask()

        let audioSession = AVAudioSession.sharedInstance()
        // 録音用のカテゴリをセット
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let inputNode = audioEngine.inputNode else { fatalError("Audio engine has no input node") }
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }

        // 録音が完了する前のリクエストを作るかどうかのフラグ。
        // trueだと現在-1回目のリクエスト結果が返ってくる模様。falseだとボタンをオフにしたときに音声認識の結果が返ってくる設定。
        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let `self` = self else { return }

            var isFinal = false

            if let result = result {
                self.label.text = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }

            // エラーがある、もしくは最後の認識結果だった場合の処理
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil

                self.button.isEnabled = true
                self.button.setTitle("音声認識スタート", for: [])
            }
        }

        // マイクから取得した音声バッファをリクエストに渡す
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
        // startの前にリソースを確保しておく。
        audioEngine.prepare()
        
        try audioEngine.start()
        
        label.text = "どうぞ喋ってください。"
    }
}

extension ViewController: SFSpeechRecognizerDelegate {
    // 音声認識の可否が変更したときに呼ばれるdelegate
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            button.isEnabled = true
            button.setTitle("音声認識スタート", for: [])
        } else {
            button.isEnabled = false
            button.setTitle("音声認識ストップ", for: .disabled)
        }
    }
}
