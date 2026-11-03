# juiz_examples_haskell

ロボット・IoT 向けミドルウェア [juiz](https://github.com/OpenJUIZ/juiz) の Haskell 版サンプル集です。
`libjuiz_sdk` は juiz の [GitHub Releases](https://github.com/OpenJUIZ/juiz/releases) のアーカイブ (0.0.26 から) を使い、Haskell 用のライブラリ hsjuiz は juiz のソースから入れます。どちらもビルド時に `build.sh` が自動で取得するので、juiz のソースを手元に用意する必要はありません。

> hsjuiz の Hackage 公開は準備中です。公開したら、juiz のソースを取得せずにそちらを使う手順に変える予定です。

Rust 版は [juiz_examples_rust](https://github.com/OpenJUIZ/juiz_examples_rust)、Python 版は [juiz_examples_python](https://github.com/OpenJUIZ/juiz_examples_python)、C++ 版は [juiz_examples_cpp](https://github.com/OpenJUIZ/juiz_examples_cpp) にあります。

`juiz` コマンドは crates.io の [juiz_app](https://crates.io/crates/juiz_app) 0.2.0 を使います (Haskell 対応は 0.0.21 から、データ型は 0.0.23 から)。

## しくみ

Haskell で書いた Process や Container は、cabal の `foreign-library` で共有ライブラリ (`lib*.so`、macOS では `lib*.dylib`、Windows では `*.dll`) としてビルドし、`juiz` コマンドが設定ファイル (`*.conf`) を読んでプラグインとして読み込みます。

Haskell のプラグインは juiz の Haskell ライブラリ hsjuiz (`bindings/hsjuiz`) を使って書き、juiz_sdk の共有ライブラリ `libjuiz_sdk` とリンクします。
どちらも `cargo install juiz_app` では入らないので、このリポジトリの [build.sh](build.sh) が次のことを行います。

1. GitHub から juiz のソースを `build/juiz` に取得する (hsjuiz を使うため。[cabal.project](cabal.project) がそこを参照する)
2. 同じ版の `libjuiz_sdk` のアーカイブを juiz の `scripts/install-juiz-sdk.sh` で `build/juiz_sdk_archive` に取得し、`build/plugins` に置く (アーカイブのない環境では、ソースの juiz_sdk を `cargo build --release -p juiz_sdk` でビルドする)
3. 同じソースの juiz-idl で、サンプル共通の型 (types/geometry.jidl) から Haskell の型を `build/gen-hs` に作る
4. `cabal build` でサンプルをビルドし、できた共有ライブラリを `build/plugins` に置く (プラグインには自分と同じ場所からライブラリを探す rpath を付ける)

## 必要なもの

- Linux、macOS、Windows (x86_64、juiz 0.0.27 から) のいずれか。Windows では Git Bash で `./build.sh` を実行し、Rust の MSVC ツールチェーン (Visual Studio か Build Tools の「C++ によるデスクトップ開発」) を使います。注意は下の「Windows でビルドするとき」を見てください
- GHC 9.6 以降と cabal。インストールは https://www.haskell.org/ghcup/ を参照してください。
- Rust (stable)。`juiz` コマンドと juiz-idl のビルドに使います。インストールは https://rustup.rs/ を参照してください。
- git、curl
- Linux では Python の開発用ファイル (`juiz` コマンドのビルドに使います。Ubuntu なら `sudo apt install python3-dev`)

hsjuiz は GHC に付いてくるパッケージ (base, text, containers, template-haskell など) だけを使うので、`cabal update` は要りません。

## 1. juiz コマンドをインストールする

```sh
cargo install juiz_app --version 0.2.0 --locked
```

`juiz` コマンドが `~/.cargo/bin` に入ります。

## 2. サンプルをビルドする

```sh
git clone https://github.com/OpenJUIZ/juiz_examples_haskell.git
cd juiz_examples_haskell
./build.sh
```

初回は juiz の取得と juiz-idl のビルドに少し時間がかかります。

macOS で、選んでいる Xcode より新しい Command Line Tools (たとえば Xcode 26 に Command Line Tools 27 の MacOSX27.0.sdk) が入っていると、GHC のリンクが `tapi error: malformed file ... unknown architecture arm64e.x1-macos` で失敗します。`build.sh` はこの組み合わせを見つけると、`DEVELOPER_DIR=/Library/Developer/CommandLineTools` にして Command Line Tools のリンカでビルドします。自分で `cabal build` するときも同じように `DEVELOPER_DIR` を付けるか、Xcode を Command Line Tools と同じ版に上げてください ([OpenJUIZ/juiz#143](https://github.com/OpenJUIZ/juiz/issues/143))。
ビルドしたプラグインは `build/plugins` に出力されます。設定ファイルは `./build/plugins` からプラグインを探すので、**リポジトリのルートで** `juiz` を実行してください。

手元に juiz のソースがある場合は、それを使うこともできます (`build/juiz` がそこへのリンクになります)。

```sh
JUIZ_SOURCE_DIR=/path/to/juiz ./build.sh
```

### Windows でビルドするとき

Git Bash で、上と同じく `./build.sh` を実行します。Linux・macOS と違うのは次の点です。

- `libjuiz_sdk` は Windows のアーカイブ (`bin\juiz_sdk.dll` とインポートライブラリ `lib\juiz_sdk.dll.lib`) を juiz の `scripts/install-juiz-sdk.ps1` で取得し、`juiz_sdk.dll` を `build/plugins` に置きます。プラグインは lib の付かない `<名前>.dll` になります。Windows に rpath は無く、juiz はプラグインの隣の `juiz_sdk.dll` を読み込みます。
- Windows の GHC は Haskell の共有ライブラリを持たないので、[juiz-examples-haskell.cabal](juiz-examples-haskell.cabal) は `foreign-library` ごとに `options: standalone` で RTS と hsjuiz を DLL に取り込み、公開する関数を [def/](def) の `<名前>.def` に並べています。ライブラリを足すときは `.def` も足してください。
- Windows では `-fno-PIC` でコンパイルします (`common plugin`)。`-fPIC` のままだと、構成子が 7 個以上ある型の `case` や `show` でプロセスが落ちます ([OpenJUIZ/juiz#262](https://github.com/OpenJUIZ/juiz/issues/262)、GHC の不具合 [ghc#24016](https://gitlab.haskell.org/ghc/ghc/-/issues/24016))。自分のプロジェクトを作るときも付けてください。
- DLL ごとに GHC のランタイムが別になるので、**別々の DLL の Container と ContainerProcess はつなげません** (呼ぶと `-602` のエラーになります)。`example_container.conf` は Windows では動かないので、Container を使うときは `example_component.conf` のように Component (1 つの DLL) にまとめてください。詳しくは juiz の [bindings/hsjuiz/README.md の「Windows」](https://github.com/OpenJUIZ/juiz/tree/main/bindings/hsjuiz#windows) を見てください。
- リポジトリは浅い場所 (`C:\Users\<名前>\juiz_examples_haskell` など) に置いてください。深い場所では、GHC の中間ファイルや `build/juiz` のパスが 260 文字を超えてビルドが失敗します ([OpenJUIZ/juiz#279](https://github.com/OpenJUIZ/juiz/issues/279))。

## 3. 動かしてみる

### Process: increment_process_hs

引数に 1 を足して返すだけの Process です ([process/IncrementProcess.hs](process/IncrementProcess.hs))。

```haskell
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module IncrementProcess () where

import Juiz

manifest :: ProcessManifest
manifest = processManifest "increment_process_hs"
  & description "Adds 1 to arg1."
  & addIntArg "arg1" "value to be incremented" 1

increment :: Int64 -> IO Int64
increment arg1 = pure (arg1 + 1)

juizProcess 'increment 'manifest
```

`manifest` で Process の名前と引数 (名前・説明・既定値) を宣言し、`juizProcess` で juiz から呼び出せるようにします。
関数の引数は `manifest` で宣言した順に渡されます。結果は `IO` でなくてもかまいません ([DecrementProcess.hs](process/DecrementProcess.hs))。

```sh
juiz -f increment_process.conf -d
```

`-d` を付けると HTTP ブローカー (8000 番ポート) を立ち上げて待機します (Ctrl+C で終了)。
別のターミナルから呼び出せます。

```sh
juiz process list
juiz process call "http://127.0.0.1:8000/process/increment0::increment_process_hs" '{"arg1": 3}' -p
# => CapsulePtr((value:Value(4), option: []))
```

`decrement_process.conf` も同じ使い方です (1 を引く Process)。

```sh
juiz -f decrement_process.conf -d
juiz process call "http://127.0.0.1:8000/process/decrement0::decrement_process_hs" '{"arg1": 3}' -p
# => CapsulePtr((value:Value(2), option: []))
```

### Process の接続: talker / listener

`talker_hs` の出力を `listener_hs` の引数 `arg1` に Push 接続し、実行コンテキスト (main_loop_ec) で 1Hz で `talker_hs` を動かします。

```sh
juiz -f talker_listener.conf -d
# talker_hs: Hello, Juiz!
# listener_hs: Hello, Juiz!
# ...
```

文字列は `Text` で受け取り、`Text` で返します ([process/Talker.hs](process/Talker.hs)、[process/Listener.hs](process/Listener.hs))。

### Container: example_container_hs

状態 (整数値) を持つ Container と、それを操作する ContainerProcess (`example_container_hs_increment`、`example_container_hs_get`) のサンプルです。
Container と ContainerProcess は別々の共有ライブラリになるので、状態の型 ([ExampleContainerState.hs](container/ExampleContainerState.hs)) を両方に入れて共有します。

Container を作る関数は、`manifest` で宣言した引数を、設定ファイルの `containers` に書いた値で受け取ります。この例では `value: 10` を初期値にしています。

```haskell
manifest :: ContainerManifest
manifest = containerManifest "example_container_hs"
  & description "Holds an integer value."
  & addIntArg "value" "initial value" 0

create :: Int64 -> IO ExampleContainer
create value = ExampleContainer <$> newIORef value

juizContainer 'create 'manifest
```

ContainerProcess は、最初の引数で Container の状態を受け取ります。

```haskell
manifest :: ProcessManifest
manifest = containerProcessManifest "example_container_hs_increment" "example_container_hs"
  & description "Adds arg1 to the value of the container."
  & addIntArg "arg1" "value to be added" 1

increment :: ExampleContainer -> Int64 -> IO Int64
increment (ExampleContainer ref) arg1 = atomicModifyIORef' ref (\v -> (v + arg1, v + arg1))

juizContainerProcess 'increment 'manifest
```

```sh
juiz -f example_container.conf -d
```

別のターミナルから呼び出すたびに値が増えていきます。

```sh
juiz container-process call "http://127.0.0.1:8000/container_process/increment0::example_container_hs_increment:container0" '{"arg1": 5}' -p
# => CapsulePtr((value:Value(15), option: []))
juiz container-process call "http://127.0.0.1:8000/container_process/get0::example_container_hs_get:container0" '{}' -p
# => CapsulePtr((value:Value(15), option: []))
```

### Component: example_component_hs

1 つのライブラリに Process・Container・ContainerProcess をまとめて入れる Component のサンプルです ([component/ExampleComponent.hs](component/ExampleComponent.hs))。
各要素の関数とマニフェストを単体のときと同じように書き、最後に `juizComponent` でまとめて公開します。

```haskell
juizComponent 'component
  [ componentProcess 'increment 'incrementManifest
  , componentContainer 'createContainer 'containerManif
  , componentContainerProcess 'containerGet 'getManifest
  , componentContainerProcess 'containerIncrement 'incrementContainerManifest
  ]
```

```sh
juiz -f example_component.conf -d
juiz process call "http://127.0.0.1:8000/process/proc0::example_component_hs_increment" '{"arg1": 1}' -p
# => CapsulePtr((value:Value(2), option: []))
juiz container-process call "http://127.0.0.1:8000/container_process/increment0::example_component_hs_container_increment:container0" '{"arg1": 5}' -p
# => CapsulePtr((value:Value(105), option: []))
juiz container-process call "http://127.0.0.1:8000/container_process/get0::example_component_hs_container_get:container0" '{}' -p
# => CapsulePtr((value:Value(105), option: []))
```

### ネームスペース: 同じ構成を並べて動かす

ネームスペースを使うと、同じ名前の Process を 1 つの System に並べて置けます。ID はクラスの後ろ・名前の前にネームスペースが入った `http://127.0.0.1:8000/process/robot1/talker0::talker_hs` の形になります。

#### 1 つの設定ファイルで 2 台分を置く: namespace.conf

`talker0` と `listener0` を `robot1` と `robot2` の 2 つのネームスペースに置き、Topic `chatter` でつなぎます。Topic 名もネームスペースの中で解決される (`robot1/chatter` と `robot2/chatter`) ので、それぞれの `listener0` には同じネームスペースの `talker0` の出力だけが届きます。

```sh
juiz -f namespace.conf -d
# talker_hs: Hello from robot1
# listener_hs: Hello from robot1
# talker_hs: Hello from robot2
# listener_hs: Hello from robot2
# ...
```

別のターミナルから、ネームスペースの列つきで一覧を出したり、ネームスペース付きの ID で呼び出したりできます。

```sh
juiz process list --long
# NAMESPACE  NAME       TYPE        ID
# /robot1    talker0    talker_hs  http://127.0.0.1:8000/process/robot1/talker0::talker_hs
# ...
juiz process call "http://127.0.0.1:8000/process/robot1/talker0::talker_hs" '{"message": "Hi"}' -p
# => CapsulePtr((value:Value("Hi"), option: []))
```

設定ファイルでは各要素に `namespace` を書きます (`/` で始めるとルートからの絶対指定)。トップレベルに `namespace` を書くと、全体の既定のネームスペースになります。

#### 同じ設定ファイルを 2 つ起動する: --namespace

`--namespace` を付けると、設定ファイルの既定のネームスペースを置き換えて起動できます。2 つのターミナルで次のように起動すると、2 つ目は 1 つ目のサブシステムになり (8001 番ポートで待ち受け)、1 つの System として扱えます。

```sh
juiz -f increment_process.conf --namespace robot1 -d
```

```sh
juiz -f increment_process.conf --namespace robot2 -d
```

```sh
juiz process list --namespace robot2
# => ["http://127.0.0.1:8001/process/robot2/increment0::increment_process_hs"]
juiz process call "http://127.0.0.1:8000/process/robot1/increment0::increment_process_hs" '{"arg1": 1}' -p
# => CapsulePtr((value:Value(2), option: []))
juiz process call "http://127.0.0.1:8001/process/robot2/increment0::increment_process_hs" '{"arg1": 10}' -p
# => CapsulePtr((value:Value(11), option: []))
```

### データ型: 言語をまたいで同じ型を使う

Process の引数と戻り値に型を付けられます。型は IDL (JIDL) で書き、生成器 `juiz-idl` で各言語の型を作ります。
このリポジトリの [types/geometry.jidl](types/geometry.jidl) は、Haskell・[Rust](https://github.com/OpenJUIZ/juiz_examples_rust)・[Python](https://github.com/OpenJUIZ/juiz_examples_python)・[C++](https://github.com/OpenJUIZ/juiz_examples_cpp) の 4 つのサンプルリポジトリで同じ中身にしてあり、どの言語で作っても型の指紋 (`@sha256:…`) が同じになります。指紋が同じ型どうしは、言語が違ってもそのままつながります。

```text
namespace examples.geometry;

record Point2D { double x = 0.0; double y = 0.0; }
record Pose2D  { Point2D position = {"x": 0.0, "y": 0.0}; double theta = 0.0; string frame_id = "map"; }
record Twist2D { double linear = 0.0; double angular = 0.0; }
```

> データ型は juiz 0.0.23 から使えます。juiz コマンドと、Python の Process が使う pyjuiz は 0.0.23 以降を入れてください。
>
> ```sh
> cargo install juiz_app --version 0.2.0 --locked
> pip install pyjuiz==0.2.0
> ```

Haskell の Process [process/PoseMove.hs](process/PoseMove.hs) (`pose_move_hs`) は、types/geometry.jidl から作った型 (`Examples.Geometry`) をそのまま引数と戻り値に使います。型は `build.sh` が `juiz-idl -g haskell` で `build/gen-hs` に作ります (`juiz-idl` は juiz のソースからビルドします)。

```cabal
foreign-library pose_move_hs
    import:           plugin
    type:             native-shared
    hs-source-dirs:   process build/gen-hs
    build-depends:    bytestring, containers, text
    other-modules:    PoseMove
                      Examples.Geometry
```

```haskell
import Juiz
import Examples.Geometry

manifest :: ProcessManifest
manifest = processManifest "pose_move_hs"
  & addTypedArg "pose" "current pose" defaultPose2D
  & addTypedArg "twist" "velocity" defaultTwist2D
  & addFloatArg "dt" "duration [s]" 1

poseMove :: Pose2D -> Twist2D -> Double -> IO Pose2D
poseMove pose twist dt = …

juizProcess 'poseMove 'manifest
```

#### Haskell と Python をつなぐ: typed_pose.conf

Python の Process ([python/](python/)) が出した `Twist2D` を Haskell の `pose_move_hs` が受け取り、`pose_move_hs` が出した `Pose2D` を Python の Process が受け取ります。Python の Process には pyjuiz が要ります。

```text
twist0 (Python, Twist2D) --Pull--> move0 (Haskell, pose_move_hs) --Push--> print0 (Python, Pose2D を表示)
```

先に Python の型を `gen/` に作ってから起動します (設定ファイルの `option.pythonpath` で `gen/` を読みます)。

```sh
juiz idl -g python -o gen types/geometry.jidl
juiz -f typed_pose.conf -d
```

別のターミナルから `move0` を実行 (execute) すると、`twist0` から速度を取ってきて動き、結果を `print0` に送ります。

```sh
curl -X PATCH "http://127.0.0.1:8000/api/process/execute?identifier=core://core/process/move0::pose_move_hs" -H "Content-Type: application/json" -d '{}'
# => {"frame_id":"map","position":{"x":0.5,"y":0.0},"theta":0.0}
```

```text
pose_move_hs: (0.00, 0.00, 0.00) -> (0.50, 0.00, 0.00)
pose_print_python receives Pose2D(x=0.50, y=0.00, theta=0.00, frame_id=map)
```

型付きの引数も、CLI や curl からは今までどおり辞書で渡せます。書かなかったフィールドは既定値になります。

```sh
juiz process call "http://127.0.0.1:8000/process/move0::pose_move_hs" '{"pose": {"position": {"x": 1.0, "y": 2.0}}, "twist": {"linear": 1.0}, "dt": 2.0}' -p
# => CapsulePtr((value:Value({"frame_id":"map","position":{"x":3.0,"y":2.0},"theta":0.0}), option: []))
```

読み込んだ型は `juiz type` で見られます。Haskell と Python の型の指紋が同じなので、1 つの型として登録されています。

```sh
juiz type list
# => ["examples.geometry.Point2D@sha256:5649ab39…","examples.geometry.Pose2D@sha256:123b8c15…","examples.geometry.Twist2D@sha256:115b9e0f…"]
juiz type show examples.geometry.Twist2D
# // examples.geometry.Twist2D@sha256:115b9e0f…
# // used by: pose_move_hs, twist_python
# ...
```

#### 型が合わないとつながらない: typed_mismatch.conf

`twist0` の `Twist2D` を `move0` の引数 `pose` (`Pose2D`) につなごうとする設定ファイルです。juiz は接続を作らず、エラーで終わります。

```sh
juiz -f typed_mismatch.conf -d
# Error:setup_objects() failed in setup in system.rs
# ...
#     2: Type examples.geometry.Twist2D@sha256:115b9e0f… cannot be read as examples.geometry.Pose2D@sha256:123b8c15… at 'Pose2D': record name examples.geometry.Twist2D does not match examples.geometry.Pose2D (add an alias to read it)
```

### Transformations: 部品の位置関係を木にする

ロボットの部品 (台車・雲台・カメラ) を Container にし、部品同士のつながり (Transform) と基点 (Anchor) を設定ファイルに書くと、juiz が各部品の位置姿勢 (ContainerPose) を計算します。

> juiz 0.2.0 から使える機能です。

`transformations.conf` の木は次のとおりです。`map` と `odom` は juiz に組み込みの Anchor で、プラグインは要りません。

```text
map (PeriodicExecutionAnchor, 10 Hz)    … 10 Hz で木をたどって位置姿勢を計算し直す
└─ odom (StaticAnchor)                  … 書き込みがあったときだけ計算し直す。map から (1, 2, 0) ずれている
   └─ base0 (台車 mobile_base_hs)        … move0 がオドメトリを setContainerPose で書く
      └─ pantilt0 (雲台 pantilt_hs)      … 台車の (0.1, 0, 0.3) に付く。pan0 がパン角を書く
         └─ camera0 (カメラ camera_hs)   … 雲台の (0.05, 0, 0.02) に付く。Transform だけ
```

部品は `component/MobileRobot.hs` の 1 つの Component (`mobile_robot_hs`) です。ContainerProcess の中では `containerPose "map"` で読み、`setContainerPose "odom" pose` で書きます。どちらも「今呼ばれている ContainerProcess の Container」が相手です。`setContainerPose` は親 → 自分の Transform を書き換えるので、子の雲台・カメラも一緒に動きます。

```haskell
move :: MobileBase -> Double -> Double -> Double -> Text -> IO Value
move (MobileBase ref) vx omega dt reference = do
  (x, y, theta) <- readIORef ref
  let x' = x + vx * cos theta * dt
      y' = y + vx * sin theta * dt
      theta' = theta + omega * dt
  writeIORef ref (x', y', theta')
  poseStampedToValue reference <$> setContainerPose reference (yawPose (x', y', 0) theta')
```

また `pose_listeners:` で、台車の位置姿勢が書かれたら Process `print0` (`pose_print_hs`) を呼ぶ Pose 通知を登録しています。

```sh
juiz -f transformations.conf -d
```

別の端末で台車を動かし、雲台を 90 度回します。

```sh
juiz container-process call "http://127.0.0.1:8000/container_process/move0::mobile_base_hs_move:base0" '{"vx": 1.0, "dt": 1.0}' -p
# => CapsulePtr((value:Value({"header":{"frame_id":"odom",...},"pose":{"orientation":{...},"position":{"x":1.0,"y":0.0,"z":0.0}}}), option: []))
juiz container-process call "http://127.0.0.1:8000/container_process/pan0::pantilt_hs_set_pan:pantilt0" '{"pan": 1.5707963267948966}' -p
```

1 つ目の呼び出しで、juiz を起動した端末に Pose 通知の出力が出ます。

```text
pose_print_hs: x=1.00 y=0.00 yaw=0.0deg (from odom)
```

カメラの位置姿勢を読みます。雲台が回ったので、カメラは台車の左 (y = 0.05) に来ています。`map` から見ると `map` → `odom` のずれ (1, 2, 0) が足されます。

```sh
juiz container pose camera0 --reference odom
# => position: x=1.1, y=0.05, z=0.32 (JSON の PoseStamped)
juiz container pose camera0 --reference map
# => position: x=2.1, y=2.05, z=0.32
juiz container-process call "http://127.0.0.1:8000/container_process/camera_pose0::camera_hs_pose:camera0" '{"reference": "map"}' -p
juiz anchor tree map
# map  position (0, 0, 0)  orientation (0, 0, 0, 1)
# └─ odom  position (1, 2, 0)  orientation (0, 0, 0, 1)
#    └─ base0  position (2, 2, 0)  orientation (0, 0, 0, 1)
#       └─ pantilt0  position (2.1, 2, 0.3)  orientation (0, 0, 0.7071067811865475, 0.7071067811865476)
#          └─ camera0  position (2.1, 2.05, 0.32)  orientation (0, 0, 0.7071067811865475, 0.7071067811865476)
```

`map` は Periodic なので、書き込みの直後に読むと最大 1 周期 (0.1 秒) 古い値が返ります。`odom` は Static なので、`setContainerPose` が戻った時点で新しい値になっています。
管理画面 (`http://127.0.0.1:8000/ui`) の「変換木」でも木と位置姿勢を見られます。

### アプリを .juizapp で配る

`packages/talker_listener/` を、1 つのファイル (`.juizapp`、zip) にまとめて配れます (juiz 0.0.28 から)。受け取った人は、GHC も cabal も無しに `juiz run` だけで動かせます。

```sh
python3 scripts/make_packages.py      # 先に ./build.sh でビルドしておく
# copied: libjuiz_sdk.so (...)
# copied: libHSbase-<版>-ghc<版>.so (...)
# ...
# Packed talker_listener 0.1.0 (x86_64-unknown-linux-gnu; ... files) into .../dist/talker_listener-0.1.0-x86_64-unknown-linux-gnu.juizapp
juiz run dist/talker_listener-0.1.0-x86_64-unknown-linux-gnu.juizapp
# talker_hs: Hello, Juiz!
# listener_hs: Hello, Juiz!
```

Haskell のプラグインは `libjuiz_sdk` のほかに GHC の共有ライブラリ (`libHSbase-*`、`libHSrts*` など) と libffi・libgmp にもリンクします。`scripts/make_packages.py` は juiz の `scripts/bundle-plugin-deps.sh` (`build.sh` が `build/juiz` に取得した juiz のソースにある) で、プラグインとそれらを `plugins/<この機械のターゲット>/` に集め、どれも隣を探すように書き換えてから `juiz pack --target <ターゲット>` を呼びます。Linux では `patchelf` が要ります (`sudo apt install patchelf` か `pip install patchelf`)。Windows の DLL は RTS と hsjuiz を中に取り込んでいるので、DLL と `juiz_sdk.dll` を写すだけです。
タグ (`v*`) を付けると、CI が Linux (x86_64) と macOS (arm64) で作った `.juizapp` をこのリポジトリの Releases に載せます。

## 構成

| パス | 内容 |
| --- | --- |
| `process/` | Process (入力と出力を持つ冪等な関数) のサンプル |
| `container/` | Container (状態を持つ) と ContainerProcess のサンプル |
| `component/` | 複数の要素を 1 つのライブラリにまとめた Component のサンプル (`MobileRobot.hs` は Transformations の部品) |
| `types/` | 4 つのサンプルリポジトリで共通に使う型 (JIDL) |
| `python/` | データ型のサンプルで Haskell の Process とつなぐ Python の Process |
| `juiz-examples-haskell.cabal` | 各サンプルを `foreign-library` として宣言する |
| `build.sh` | juiz のソースと libjuiz_sdk・juiz-idl を用意し、型を作ってサンプルをビルドし、`build/plugins` に置く |
| `*.conf` | 各サンプルを動かすための juiz の設定ファイル |
| `packages/` | `.juizapp` にするアプリのマニフェストと設定ファイル |
| `scripts/make_packages.py` | ビルドしたプラグインと依存するライブラリを `packages/` のアプリに集め、`dist/` に `.juizapp` を作るスクリプト |
| `tests/test_examples.py` | 上のサンプルを起動して呼び出し、結果を確かめるテスト (ビルドのあと `python3 tests/test_examples.py`)。CI でも実行する |

## 自分で書くときは

### このリポジトリに足す

`.hs` ファイルを作り、[juiz-examples-haskell.cabal](juiz-examples-haskell.cabal) に `foreign-library` を追加します。
ライブラリ名は設定ファイルに書く名前 (`process_factories` などのキー) と同じにしてください。juiz はその名前から `lib<名前>.so` (macOS では `lib<名前>.dylib`、Windows では `<名前>.dll`) を探します。

```cabal
foreign-library my_process
    import:           plugin
    type:             native-shared
    hs-source-dirs:   process
    other-modules:    MyProcess
```

`import: plugin` で、hsjuiz への依存と、juiz から読み込むのに必要な `-threaded` などの設定が入ります。
hsjuiz の書き方の詳細は juiz の [bindings/hsjuiz/README.md](https://github.com/OpenJUIZ/juiz/blob/main/bindings/hsjuiz/README.md) を参照してください。

注意:

- 1 つの juiz で読み込む Haskell のプラグインは、すべて同じ GHC でビルドしてください (GHC のランタイムを共有するため)。
- プラグインは GHC のライブラリと `build/dist-newstyle` の中の hsjuiz を参照するので、ビルドしたあと GHC を入れ替えたり `build` を消したりしたら、もう一度 `./build.sh` を実行してください。

### 自分のプロジェクトで使う

いちばん手早いのは、このリポジトリの [build.sh](build.sh)・[cabal.project](cabal.project)・[juiz-examples-haskell.cabal](juiz-examples-haskell.cabal) (`common plugin` の部分) をひな形にすることです。

自分で用意するときは、`juiz` コマンドと同じ版の `libjuiz_sdk` のアーカイブを取得し、juiz のソースを同じ版のタグで取得して、`cabal.project` で hsjuiz をそのソースから使います。

```sh
curl -fsSL https://raw.githubusercontent.com/OpenJUIZ/juiz/main/scripts/install-juiz-sdk.sh | sh -s -- 0.2.0
# => ~/.juiz/sdk/0.2.0/lib/libjuiz_sdk.so (macOS は .dylib)
git clone --depth 1 --branch v0.2.0 https://github.com/OpenJUIZ/juiz.git ~/juiz-0.2.0
```

```cabal
-- cabal.project
packages: . /home/me/juiz-0.2.0/bindings/hsjuiz

-- hsjuiz は libjuiz_sdk にリンクする。rpath は、Template Haskell を動かすときに GHC が
-- hsjuiz と一緒に libjuiz_sdk を読み込むために要る
package hsjuiz
  extra-lib-dirs: /home/me/.juiz/sdk/0.2.0/lib
  ghc-options: -optl-Wl,-rpath,/home/me/.juiz/sdk/0.2.0/lib
```

自分のパッケージの `.cabal` では、`foreign-library` に `type: native-shared`、`build-depends: base, hsjuiz`、`ghc-options: -threaded` を書きます。
juiz の版を上げるときは、`juiz` コマンド・`libjuiz_sdk`・juiz のソース (タグ) の版をそろえてください。

## juiz の版について

`build.sh` が取得する juiz の版は `JUIZ_GIT_REF` で決まります。既定値は `v0.2.0` で、上の手順で入れた juiz_app 0.2.0 と組み合わせて使います。タグ (`v<版>`) を指定すると、その版の `libjuiz_sdk` のアーカイブを使います。コミットを指定したときや `JUIZ_SOURCE_DIR`・`JUIZ_SDK_FROM_SOURCE=1` を指定したときは、ソースから `libjuiz_sdk` をビルドします。
別の版を使うときは、`juiz` コマンドを入れた版と合わせて指定してください。

```sh
JUIZ_GIT_REF=<タグかコミット> ./build.sh
```

## ライセンス

このリポジトリのサンプルは、次のどちらかのライセンスを選んで利用できます(デュアルライセンス)。

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) または <https://www.apache.org/licenses/LICENSE-2.0>)
- MIT License ([LICENSE-MIT](LICENSE-MIT) または <https://opensource.org/licenses/MIT>)

Licensed under either of Apache License, Version 2.0 or MIT license at your option.

### コントリビューション

明示的に別の意思表示をしない限り、このリポジトリに提出されたコントリビューションは、Apache-2.0 ライセンスの定義に従い、追加の条件なしに上記と同じデュアルライセンスで提供されるものとします。

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.
