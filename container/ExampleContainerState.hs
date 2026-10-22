-- | example_container_hs の状態の型。
--
-- Container (ExampleContainer.hs) と ContainerProcess (ExampleContainerIncrement.hs など) は
-- 別々の共有ライブラリになるので、どちらからもこのモジュールを使って型をそろえる。
module ExampleContainerState
  ( ExampleContainer (..)
  ) where

import Data.IORef (IORef)
import Data.Int (Int64)

-- | 保持している値。ContainerProcess が書き換えるので IORef に入れる
newtype ExampleContainer = ExampleContainer (IORef Int64)
