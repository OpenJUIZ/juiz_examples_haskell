# juiz_examples_haskell

ロボット・IoT 向けミドルウェア [juiz](https://github.com/OpenJUIZ/juiz) の Haskell 版サンプル集です。
Haskell 用のライブラリ hsjuiz と `libjuiz_sdk` は、ビルド時に `build.sh` が juiz のリポジトリから自動で取得するので、juiz のソースを手元に用意する必要はありません。

Rust 版は [juiz_examples_rust](https://github.com/OpenJUIZ/juiz_examples_rust)、Python 版は [juiz_examples_python](https://github.com/OpenJUIZ/juiz_examples_python)、C++ 版は [juiz_examples_cpp](https://github.com/OpenJUIZ/juiz_examples_cpp) にあります。

> **juiz の版について**: Haskell 対応 (`language: "haskell"` と hsjuiz) はまだ crates.io / PyPI に公開した juiz (0.0.20) に入っていません。
> 公開されるまでは、juiz の GitHub のコミット `f6472b68385c86c185700ee3ac697202234f064d` を使います (下の手順のとおり)。

## しくみ

Haskell で書いた Process や Container は、cabal の `foreign-library` で共有ライブラリ (`lib*.so`、macOS では `lib*.dylib`) としてビルドし、`juiz` コマンドが設定ファイル (`*.conf`) を読んでプラグインとして読み込みます。

Haskell のプラグインは juiz の Haskell ライブラリ hsjuiz (`bindings/hsjuiz`) を使って書き、juiz_sdk の共有ライブラリ `libjuiz_sdk` とリンクします。
どちらも `cargo install juiz_app` では入らないので、このリポジトリの [build.sh](build.sh) が次のことを行います。

1. GitHub から juiz のソースを `build/juiz` に取得する (hsjuiz を使うため。[cabal.project](cabal.project) がそこを参照する)
2. その中の juiz_sdk を `cargo build --release -p juiz_sdk` でビルドし、`libjuiz_sdk` を `build/plugins` に置く
3. `cabal build` でサンプルをビルドし、できた共有ライブラリを `build/plugins` に置く (プラグインには自分と同じ場所からライブラリを探す rpath を付ける)

## 必要なもの

- Linux または macOS
- GHC 9.6 以降と cabal。インストールは https://www.haskell.org/ghcup/ を参照してください。
- Rust (stable)。インストールは https://rustup.rs/ を参照してください。
- git
- Linux では Python の開発用ファイル (`juiz` コマンドのビルドに使います。Ubuntu なら `sudo apt install python3-dev`)

hsjuiz は GHC に付いてくるパッケージ (base, text, containers, template-haskell など) だけを使うので、`cabal update` は要りません。

## 1. juiz コマンドをインストールする

```sh
cargo install juiz_app --git https://github.com/OpenJUIZ/juiz.git --rev f6472b68385c86c185700ee3ac697202234f064d --locked
```

`juiz` コマンドが `~/.cargo/bin` に入ります。

macOS で Python 3.14 が入っている場合は、juiz が使う PyO3 が対応していないためビルドに失敗します。Python 3.13 を入れて `PYO3_PYTHON=python3.13` を付けて実行してください。

## 2. サンプルをビルドする

```sh
git clone https://github.com/OpenJUIZ/juiz_examples_haskell.git
cd juiz_examples_haskell
./build.sh
```

初回は juiz の取得と juiz_sdk のビルドに少し時間がかかります。
ビルドしたプラグインは `build/plugins` に出力されます。設定ファイルは `./build/plugins` からプラグインを探すので、**リポジトリのルートで** `juiz` を実行してください。

手元に juiz のソースがある場合は、それを使うこともできます (`build/juiz` がそこへのリンクになります)。

```sh
JUIZ_SOURCE_DIR=/path/to/juiz ./build.sh
```

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

## 構成

| パス | 内容 |
| --- | --- |
| `process/` | Process (入力と出力を持つ冪等な関数) のサンプル |
| `container/` | Container (状態を持つ) と ContainerProcess のサンプル |
| `component/` | 複数の要素を 1 つのライブラリにまとめた Component のサンプル |
| `juiz-examples-haskell.cabal` | 各サンプルを `foreign-library` として宣言する |
| `build.sh` | juiz のソースと libjuiz_sdk を用意し、サンプルをビルドして `build/plugins` に置く |
| `*.conf` | 各サンプルを動かすための juiz の設定ファイル |
| `tests/test_examples.py` | 上のサンプルを起動して呼び出し、結果を確かめるテスト (ビルドのあと `python3 tests/test_examples.py`)。CI でも実行する |

## 自分で書くときは

`.hs` ファイルを作り、[juiz-examples-haskell.cabal](juiz-examples-haskell.cabal) に `foreign-library` を追加します。
ライブラリ名は設定ファイルに書く名前 (`process_factories` などのキー) と同じにしてください。juiz はその名前から `lib<名前>.so` を探します。

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

## juiz の版について

`build.sh` が取得する juiz の版は `JUIZ_GIT_REF` で決まります。既定値は上の手順で `juiz` コマンドを入れたコミットです。
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
