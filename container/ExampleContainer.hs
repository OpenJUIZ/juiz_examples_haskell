{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
-- | 整数値を 1 つ保持する Container (example_container_hs)。
-- 初期値は設定ファイルの containers に書いた value (無ければ 0)。
module ExampleContainer () where

import Juiz

import ExampleContainerState

manifest :: ContainerManifest
manifest = containerManifest "example_container_hs"
  & description "Holds an integer value."
  & addIntArg "value" "initial value" 0

create :: Int64 -> IO ExampleContainer
create value = ExampleContainer <$> newIORef value

juizContainer 'create 'manifest
