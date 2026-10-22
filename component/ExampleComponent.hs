{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
-- | 1 つのライブラリに Process・Container・ContainerProcess をまとめた Component (example_component_hs)。
--
-- 各要素の関数とマニフェストを書き、最後に juizComponent でまとめて公開する。
module ExampleComponent () where

import Juiz

component :: ComponentManifest
component = componentManifest "example_component_hs"
  & description "Haskell component example."

-- Process: arg1 に 1 を足して返す
incrementManifest :: ProcessManifest
incrementManifest = processManifest "example_component_hs_increment"
  & description "Adds 1 to arg1."
  & addIntArg "arg1" "value to be incremented" 1

increment :: Int64 -> Int64
increment arg1 = arg1 + 1

-- Container: 整数値を 1 つ保持する。
-- Component では Container と ContainerProcess が同じライブラリに入るので、状態の型を別のモジュールに分けなくてよい
newtype ComponentContainer = ComponentContainer (IORef Int64)

containerManif :: ContainerManifest
containerManif = containerManifest "example_component_hs_container"
  & description "Holds an integer value."
  & addIntArg "value" "initial value" 0

createContainer :: Int64 -> IO ComponentContainer
createContainer value = ComponentContainer <$> newIORef value

-- ContainerProcess: Container の値を返す
getManifest :: ProcessManifest
getManifest = containerProcessManifest "example_component_hs_container_get" "example_component_hs_container"
  & description "Returns the value of the container."

containerGet :: ComponentContainer -> IO Int64
containerGet (ComponentContainer ref) = readIORef ref

-- ContainerProcess: Container の値に arg1 を足す
incrementContainerManifest :: ProcessManifest
incrementContainerManifest =
  containerProcessManifest "example_component_hs_container_increment" "example_component_hs_container"
    & description "Adds arg1 to the value of the container."
    & addIntArg "arg1" "value to be added" 1

containerIncrement :: ComponentContainer -> Int64 -> IO Int64
containerIncrement (ComponentContainer ref) arg1 = atomicModifyIORef' ref (\v -> (v + arg1, v + arg1))

juizComponent 'component
  [ componentProcess 'increment 'incrementManifest
  , componentContainer 'createContainer 'containerManif
  , componentContainerProcess 'containerGet 'getManifest
  , componentContainerProcess 'containerIncrement 'incrementContainerManifest
  ]
