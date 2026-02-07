---
name: tca-feature-development
description: VoiceYourTextアプリでThe Composable Architecture(TCA)を使用した新機能開発をサポートします。Reducer、State、Action、Dependencyの実装パターンに従い、テスト可能で保守性の高いコードを作成します。
---

# TCA Feature Development Skill

The Composable Architecture(TCA)パターンに従った機能開発をサポートするスキルです。

## 概要

このスキルは以下の操作をサポートします:
- TCAを使用した新機能の実装
- 既存機能のTCAパターンへのリファクタリング
- Dependency Injectionの実装
- ReducerのテストコードGENERATION
- ViewActionパターンの適用

## Instructions

### 1. 新しいTCA Featureを作成する

**目的**: TCAパターンに従った新しい機能を実装する

**手順**:
1. テンプレートファイルを参照: `iOS/VoiceYourText/Templates/ModernReducerTemplate.swift`
2. 必要なファイルを作成:
   - `{FeatureName}Feature.swift` - Reducer実装
   - `{FeatureName}View.swift` - SwiftUI View
   - `{FeatureName}Tests.swift` - Unit tests
3. Reducer構造を定義:
   ```swift
   @Reducer
   struct FeatureNameFeature {
       @ObservableState
       struct State: Equatable { }

       enum Action: ViewAction, BindableAction {
           case binding(BindingAction<State>)
           case view(View)

           enum View { }
       }

       var body: some ReducerOf<Self> {
           BindingReducer()
           Reduce { state, action in
               switch action {
               case .view(let viewAction):
                   switch viewAction {
                   // Handle view actions
                   }
               case .binding:
                   return .none
               }
           }
       }
   }
   ```

### 2. ViewActionパターンを適用する

**目的**: ViewとReducerの責任を明確に分離する

**手順**:
1. Actionを`ViewAction`と`BindableAction`に準拠させる
2. View専用のアクションを`View` enumに定義
3. Viewで`@ViewAction(for: ReducerType.self)`を使用
4. `send(.view(.actionName))`でアクションを送信

**例**:
```swift
// Reducer
enum Action: ViewAction, BindableAction {
    case binding(BindingAction<State>)
    case view(View)

    enum View {
        case onAppear
        case playButtonTapped
        case stopButtonTapped
    }
}

// View
@ViewAction(for: FeatureReducer.self)
struct FeatureView: View {
    @Bindable var store: StoreOf<FeatureReducer>

    var body: some View {
        Button("Play") {
            send(.playButtonTapped)
        }
        .onAppear {
            send(.onAppear)
        }
    }
}
```

### 3. Dependencyを実装する

**目的**: 外部サービスやAPIをテスト可能な形で注入する

**手順**:
1. `@DependencyClient`でクライアントを定義
2. 必要なメソッドを宣言
3. `liveValue`でライブ実装を提供
4. `testValue`でテスト用モックを提供

**例**:
```swift
@DependencyClient
struct SpeechSynthesizerClient {
    var speak: (AVSpeechUtterance) async throws -> Void
    var stopSpeaking: () async -> Bool
}

extension SpeechSynthesizerClient: DependencyKey {
    static let liveValue = Self(
        speak: { utterance in
            // Real implementation
        },
        stopSpeaking: {
            // Real implementation
        }
    )

    static let testValue = Self()
}

extension DependencyValues {
    var speechSynthesizer: SpeechSynthesizerClient {
        get { self[SpeechSynthesizerClient.self] }
        set { self[SpeechSynthesizerClient.self] = newValue }
    }
}
```

### 4. Effectsを使用した非同期処理

**目的**: 副作用を伴う非同期処理を実装する

**手順**:
1. `.run`でEffectを返す
2. `send`を使用してアクションを送信
3. エラーハンドリングを実装

**例**:
```swift
case .view(.loadData):
    return .run { send in
        do {
            let data = try await apiClient.fetchData()
            await send(.dataLoaded(data))
        } catch {
            await send(.dataLoadFailed(error))
        }
    }
```

### 5. 子Reducerの統合

**目的**: 親Reducerに子Reducerを統合する

**手順**:
1. 親StateにOptional子Stateを追加: `@Presents var child: ChildFeature.State?`
2. 親Actionに子Actionを追加: `case child(PresentationAction<ChildFeature.Action>)`
3. `body`で`.ifLet`を使用

**例**:
```swift
@Reducer
struct ParentFeature {
    @ObservableState
    struct State {
        @Presents var child: ChildFeature.State?
    }

    enum Action {
        case child(PresentationAction<ChildFeature.Action>)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            // Parent logic
        }
        .ifLet(\.$child, action: \.child) {
            ChildFeature()
        }
    }
}
```

## Usage Examples

### 例1: 新しいプレイヤー機能の実装

**ユーザーの要求**:
> 「音声プレイヤー機能をTCAで実装してほしい」

**実行内容**:
1. `NowPlayingFeature.swift`を作成
2. State(isPlaying, currentTitle, progress)を定義
3. Actions(startPlaying, stopPlaying, updateProgress)を定義
4. Reducerでロジックを実装
5. `NowPlayingView.swift`でUIを作成

**結果**: 再利用可能でテスト可能な音声プレイヤー機能が完成

### 例2: 既存コードのTCAリファクタリング

**ユーザーの要求**:
> 「このViewControllerをTCAに変換してほしい」

**実行内容**:
1. ViewControllerの状態をStateに抽出
2. ユーザーアクションをView Actionに変換
3. ビジネスロジックをReducerに移動
4. SwiftUIでViewを再実装

**結果**: テスト可能で予測可能な状態管理

### 例3: Dependencyの追加

**ユーザーの要求**:
> 「API通信をDependency Injectionで実装したい」

**実行内容**:
1. `@DependencyClient`でAPIClientを定義
2. `liveValue`で実装
3. Reducerで`@Dependency(\.apiClient)`を使用

**結果**: テスト時にモックを注入可能な設計

## Key Files

- `iOS/VoiceYourText/Templates/ModernReducerTemplate.swift` - TCAテンプレート
- `iOS/VoiceYourText/Features/NowPlaying/NowPlayingFeature.swift` - プレイヤー機能の実装例
- `iOS/VoiceYourText/PDFReader/PDFReaderFeature.swift` - PDF機能の実装例
- `iOS/VoiceYourText/Features/UserDictionary/UserDictionaryManager.swift` - Dependency実装例
- `iOS/VoiceYourTextTests/PDFReaderFeatureTests.swift` - Reducerテストの例

## Troubleshooting

### 問題1: Stateの変更がViewに反映されない

**原因**: `@ObservableState`が不足しているか、`@Bindable`が正しく使用されていない

**解決策**:
1. StateにEquatable準拠を確認
2. Reducerに`@ObservableState`を付与
3. Viewで`@Bindable var store`を使用

### 問題2: Actionが実行されない

**原因**: Reduce内でアクションのケースが処理されていない

**解決策**:
1. `switch action`で全ケースをカバー
2. `.none`を返すべき場所で忘れずに返す
3. コンパイラの網羅性チェックを有効化

### 問題3: Effectが無限ループする

**原因**: Effect内で同じアクションを送信し続けている

**解決策**:
1. 状態チェックを追加して条件付き実行
2. `.cancellable(id:)`でキャンセル可能にする
3. ログでアクションフローを確認

### 問題4: テストでDependencyがクラッシュする

**原因**: `testValue`が未実装

**解決策**:
1. すべてのDependencyに`testValue`を実装
2. テストで`.unimplemented`を使用して未実装メソッドを検出
3. 必要に応じてモック実装を提供

## Best Practices

1. **State は値型**: ClassではなくStructを使用
2. **Action は軽量**: データはStateに保存、Actionは指示のみ
3. **Effect は純粋**: 副作用は`.run`内のみ
4. **Dependency は抽象**: プロトコルまたはクライアントを使用
5. **View は薄く**: ロジックはすべてReducerに
6. **テスト駆動**: Reducerは純粋関数なのでテストしやすい

## Notes

- ViewActionパターンは現代的なTCAのベストプラクティス
- `@ObservableState`はSwiftUI統合を改善
- `@Presents`はナビゲーションとモーダルに使用
- `BindingReducer`は双方向バインディングを自動処理
- Dependencyは`@Dependency`プロパティラッパーで注入
- テストでは`TestStore`を使用して状態遷移を検証
