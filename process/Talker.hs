{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
-- | 文字列を出力する Process (talker_hs)。引数は無い。
module Talker () where

import qualified Data.Text.IO as T
import System.IO (hFlush, stdout)

import Juiz

manifest :: ProcessManifest
manifest = processManifest "talker_hs"
  & description "Outputs a message."

talker :: IO Text
talker = do
  let message = "Hello, Juiz!"
  T.putStrLn ("talker_hs: " <> message)
  -- 標準出力がファイルやパイプのときは Haskell の出力がためこまれるので、すぐに書き出す
  hFlush stdout
  pure message

juizProcess 'talker 'manifest
