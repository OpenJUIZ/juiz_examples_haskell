{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
-- | example_container_hs の値に arg1 を足し、足した後の値を返す ContainerProcess
-- (example_container_hs_increment)。
module ExampleContainerIncrement () where

import Juiz

import ExampleContainerState

manifest :: ProcessManifest
manifest = containerProcessManifest "example_container_hs_increment" "example_container_hs"
  & description "Adds arg1 to the value of the container."
  & addIntArg "arg1" "value to be added" 1

-- | 最初の引数で Container の状態を受け取る
increment :: ExampleContainer -> Int64 -> IO Int64
increment (ExampleContainer ref) arg1 = atomicModifyIORef' ref (\v -> (v + arg1, v + arg1))

juizContainerProcess 'increment 'manifest
