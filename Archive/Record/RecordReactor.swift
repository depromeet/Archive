//
//  RecordReactor.swift
//  Archive
//
//  Created by hanwe on 2021/10/24.
//

import RxSwift
import RxRelay
import RxFlow
import ReactorKit
import Photos
import UIKit

class RecordReactor: Reactor, Stepper {
    // MARK: private property
    
    private let model: RecordModelProtocol
    
    // MARK: internal property
    
    let steps = PublishRelay<Step>()
    let initialState = State()
    let moveToConfig: PublishSubject<Void>
    let error: PublishSubject<String>
    let isAllDataSetted: PublishSubject<Bool>
    
    // MARK: lifeCycle
    
    init(model: RecordModelProtocol) {
        self.model = model
        self.moveToConfig = .init()
        self.error = .init()
        self.isAllDataSetted = .init()
    }
    
    enum Action {
        case moveToSelectEmotion(Emotion?)
        case setEmotion(Emotion)
        case setRecordInfo(ContentsRecordModelData)
        case moveToPhotoSelet
        case setImages([UIImage])
        case setThumbnailImage(UIImage)
        case setImageInfos([ImageInfo])
        case record
    }
    
    enum Mutation {
        case setEmotion(Emotion)
        case setThumbnailImage(UIImage)
        case setImages([UIImage])
    }
    
    struct State {
        var currentEmotion: Emotion?
        var thumbnailImage: UIImage?
        var images: [UIImage]?
    }
    
    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .moveToSelectEmotion(let emotion):
            steps.accept(ArchiveStep.recordEmotionEditIsRequired(emotion))
            return .empty()
        case .setEmotion(let emotion):
            self.model.emotion = emotion
            return .just(.setEmotion(emotion))
        case .moveToPhotoSelet:
            checkPhotoAuth(completion: { [weak self] in
                self?.steps.accept(ArchiveStep.recordImageSelectIsRequired(self?.model.emotion ?? .fun))
            })
            return .empty()
        case .setRecordInfo(let info):
            self.model.recordInfo = info
            checkIsAllDataSetted()
            return .empty()
        case .setImages(let images):
            return .just(.setImages(images))
        case .setThumbnailImage(let image):
            self.model.thumbnailImage = image
            checkIsAllDataSetted()
            return .just(.setThumbnailImage(image))
        case .setImageInfos(let infos):
            self.model.imageInfos = infos
            checkIsAllDataSetted()
            return .empty()
        case .record:
            guard let contents = self.model.recordInfo else { return .empty() }
            guard let thumbnailImage = self.model.thumbnailImage else { return .empty() }
            guard let emotion = self.model.emotion else { return .empty() }
            let imageInfos = self.model.imageInfos
            steps.accept(ArchiveStep.recordUploadIsRequired(contents, thumbnailImage, emotion, imageInfos))
            return .empty()
        }
    }
    
    func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        switch mutation {
        case .setEmotion(let emotion):
            newState.currentEmotion = emotion
        case .setThumbnailImage(let image):
            newState.thumbnailImage = image
        case .setImages(let images):
            newState.images = images
        }
        return newState
    }
    
    // MARK: private function
    
    private func checkPhotoAuth(completion: (() -> Void)?) {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized:
            completion?()
        case .denied, .restricted :
            self.moveToConfig.onNext(())
        case .notDetermined:
            requestPhotoAuth(completion: completion)
        case .limited:
            break
        @unknown default:
            break
        }
    }
    
    private func requestPhotoAuth(completion: (() -> Void)?) {
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] (status) in
                switch status {
                case .authorized:
                    completion?()
                case .denied, .restricted, .notDetermined, .limited:
                    self?.error.onNext("티켓 기록 사진을 선택하려면 사진 라이브러리 접근권한이 필요합니다.")
                @unknown default:
                    break
                }
            }
        } else {
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                switch status {
                case .authorized:
                    completion?()
                case .denied, .restricted, .notDetermined, .limited:
                    self?.error.onNext("티켓 기록 사진을 선택하려면 사진 라이브러리 접근권한이 필요합니다.")
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func checkIsAllDataSetted() {
        if self.model.isAllDataSetted() {
            self.isAllDataSetted.onNext(true)
        } else {
            self.isAllDataSetted.onNext(false)
        }
    }
    
    // MARK: internal function
}
