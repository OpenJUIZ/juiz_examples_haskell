#!/usr/bin/env bash
# サンプルをビルドし、juiz が読み込む共有ライブラリを build/plugins に置く。
#
# Haskell の機能要素は juiz の Haskell ライブラリ hsjuiz (bindings/hsjuiz) を使って書き、
# juiz_sdk の共有ライブラリ (libjuiz_sdk.so / libjuiz_sdk.dylib) とリンクする。
# どちらも crates.io の juiz_app に同梱されていない。
# libjuiz_sdk は GitHub Releases のアーカイブ (0.0.26 から) を取得し、hsjuiz は juiz のソースから使う
# (hsjuiz は Hackage での公開を準備中。公開したら、ソースを取得せずにそちらを使う形に変える予定)。
#
#   JUIZ_SOURCE_DIR を指定した場合: そのディレクトリの juiz のソースを使う
#   指定しない場合: GitHub から JUIZ_GIT_REF の版を build/juiz に取得する
#
# 1. juiz のソースを build/juiz に用意する (hsjuiz を使うため。cabal.project が参照する)
# 2. libjuiz_sdk を build/plugins に置く。JUIZ_GIT_REF がタグ (v<版>) なら、その版のアーカイブを
#    juiz の scripts/install-juiz-sdk.sh で build/juiz_sdk_archive に取得する。
#    JUIZ_SOURCE_DIR を指定した場合、タグでない場合、JUIZ_SDK_FROM_SOURCE=1 の場合、
#    アーカイブのない環境では、ソースの juiz_sdk を cargo build --release -p juiz_sdk でビルドする
# 3. juiz-idl を同じソースからビルドし、サンプル共通の型 (types/geometry.jidl) から Haskell の型を build/gen-hs に作る
# 4. cabal build でサンプルをビルドし、できた共有ライブラリを build/plugins に置く
#    (プラグインには自分と同じ場所から libjuiz_sdk を探す rpath が付く。juiz-examples-haskell.cabal を参照)
set -euo pipefail

JUIZ_GIT_REPOSITORY="${JUIZ_GIT_REPOSITORY:-https://github.com/OpenJUIZ/juiz.git}"
# 使用する juiz の版 (タグかコミット)。juiz コマンドを入れた版と合わせる
JUIZ_GIT_REF="${JUIZ_GIT_REF:-v0.0.28}"
JUIZ_SOURCE_DIR="${JUIZ_SOURCE_DIR:-}"
JUIZ_SDK_FROM_SOURCE="${JUIZ_SDK_FROM_SOURCE:-}"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build_dir="$root/build"
juiz_dir="$build_dir/juiz"
plugin_dir="$build_dir/plugins"

case "$(uname -s)" in
    Darwin) ext=dylib ;;
    *) ext=so ;;
esac

mkdir -p "$build_dir" "$plugin_dir"

# 1. juiz のソース
if [[ -n "$JUIZ_SOURCE_DIR" ]]; then
    JUIZ_SOURCE_DIR="$(cd "$JUIZ_SOURCE_DIR" && pwd)"
    if [[ -L "$juiz_dir" || ! -e "$juiz_dir" ]]; then
        ln -sfn "$JUIZ_SOURCE_DIR" "$juiz_dir"
    else
        echo "error: $juiz_dir がすでにあります。JUIZ_SOURCE_DIR を使うときは消してから実行してください。" >&2
        exit 1
    fi
    echo "juiz のソース: $JUIZ_SOURCE_DIR"
else
    if [[ -L "$juiz_dir" ]]; then
        rm "$juiz_dir"
    fi
    if [[ "$(cat "$build_dir/juiz.ref" 2>/dev/null)" != "$JUIZ_GIT_REF" ]]; then
        echo "juiz $JUIZ_GIT_REF を $JUIZ_GIT_REPOSITORY から取得します"
        rm -rf "$juiz_dir"
        git init -q "$juiz_dir"
        git -C "$juiz_dir" fetch -q --depth 1 "$JUIZ_GIT_REPOSITORY" "$JUIZ_GIT_REF"
        git -C "$juiz_dir" checkout -q FETCH_HEAD
        echo "$JUIZ_GIT_REF" > "$build_dir/juiz.ref"
    fi
fi

if [[ ! -e "$juiz_dir/bindings/hsjuiz/hsjuiz.cabal" ]]; then
    echo "error: juiz の Haskell ライブラリが見つかりません: $juiz_dir/bindings/hsjuiz" >&2
    echo "       hsjuiz が入っている版の juiz を指定してください。" >&2
    exit 1
fi

# 2. libjuiz_sdk
sdk_lib=""
if [[ -z "$JUIZ_SOURCE_DIR" && -z "$JUIZ_SDK_FROM_SOURCE" && "$JUIZ_GIT_REF" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    sdk_archive_dir="$build_dir/juiz_sdk_archive/${JUIZ_GIT_REF#v}"
    if [[ -e "$sdk_archive_dir/lib/libjuiz_sdk.$ext" ]] \
        || sh "$juiz_dir/scripts/install-juiz-sdk.sh" "$JUIZ_GIT_REF" "$sdk_archive_dir"; then
        sdk_lib="$sdk_archive_dir/lib/libjuiz_sdk.$ext"
    else
        echo "libjuiz_sdk のアーカイブを取得できなかったので、ソースからビルドします"
    fi
fi
if [[ -z "$sdk_lib" ]]; then
    cargo build --release -p juiz_sdk \
        --manifest-path "$juiz_dir/Cargo.toml" \
        --target-dir "$build_dir/juiz_sdk"
    sdk_lib="$build_dir/juiz_sdk/release/libjuiz_sdk.$ext"
fi
cp "$sdk_lib" "$plugin_dir/"

# 3. 型。Python の型を置く gen/ (examples/geometry) とは分ける
# (macOS の大文字小文字を区別しないファイルシステムでは Examples/ と examples/ が同じディレクトリになるため)
cargo build --release -p juiz_idl \
    --manifest-path "$juiz_dir/Cargo.toml" \
    --target-dir "$build_dir/juiz_sdk"
"$build_dir/juiz_sdk/release/juiz-idl" -g haskell -o "$build_dir/gen-hs" "$root/types/geometry.jidl" > /dev/null

# 4. サンプル
cd "$root"
# macOS では、GHC がリンクのときに Command Line Tools の SDK (/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk)
# を -L で渡す。選ばれている Xcode より Command Line Tools の SDK の版が新しいと、Xcode のリンカがその SDK の
# .tbd を読めずにリンクが失敗する (tapi error: unknown architecture、OpenJUIZ/juiz#143)。
# そのときは DEVELOPER_DIR で Command Line Tools のリンカと SDK を使う。DEVELOPER_DIR を指定済みなら何もしない
if [[ "$(uname -s)" == Darwin && -z "${DEVELOPER_DIR:-}" ]]; then
    clt_dir=/Library/Developer/CommandLineTools
    selected_dir="$(xcode-select -p 2>/dev/null || true)"
    if [[ -d "$clt_dir/SDKs/MacOSX.sdk" && "$selected_dir" != "$clt_dir" ]]; then
        clt_sdk="$(basename "$(cd "$clt_dir/SDKs/MacOSX.sdk" && pwd -P)" .sdk)"
        clt_sdk="${clt_sdk#MacOSX}"
        selected_sdk="$(xcrun --sdk macosx --show-sdk-version 2>/dev/null || true)"
        if [[ "${clt_sdk%%.*}" =~ ^[0-9]+$ && "${selected_sdk%%.*}" =~ ^[0-9]+$ \
            && "${clt_sdk%%.*}" -gt "${selected_sdk%%.*}" ]]; then
            echo "Command Line Tools の SDK ($clt_sdk) が $selected_dir の SDK ($selected_sdk) より新しいので、"
            echo "DEVELOPER_DIR=$clt_dir でビルドします (OpenJUIZ/juiz#143)"
            export DEVELOPER_DIR="$clt_dir"
        fi
    fi
fi
# Template Haskell を動かすときに GHC が hsjuiz と一緒に libjuiz_sdk を読み込むので、探す場所に加える
export LD_LIBRARY_PATH="$plugin_dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export DYLD_LIBRARY_PATH="$plugin_dir${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
cabal build all --builddir="$build_dir/dist-newstyle" --extra-lib-dirs="$plugin_dir"

# juiz は設定ファイルに書いた名前 NAME から lib<NAME>.so (macOS では lib<NAME>.dylib) を探す
for name in $(sed -n -E 's/^foreign-library[[:space:]]+//p' juiz-examples-haskell.cabal); do
    lib=$(find "$build_dir/dist-newstyle" -name "lib$name.$ext" -type f | head -n 1)
    if [[ -z "$lib" ]]; then
        echo "error: lib$name.$ext が見つかりません" >&2
        exit 1
    fi
    cp "$lib" "$plugin_dir/"
done
# hsjuiz の共有ライブラリも隣に置く (プラグインは $ORIGIN からも探す)
find "$build_dir/dist-newstyle" -name "libHShsjuiz-*.$ext" -type f -exec cp {} "$plugin_dir/" \;
echo "プラグインを $plugin_dir に置きました"
