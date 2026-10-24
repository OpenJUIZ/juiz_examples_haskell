{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
-- | 文字列 message (既定は "Hello, Juiz!") を出力する Process (talker_hs)。
module Talker () where

import qualified Data.Text.IO as T
import System.IO (hFlush, stdout)

import Juiz

manifest :: ProcessManifest
manifest = processManifest "talker_hs"
  & description "Outputs a message."
  & addStringArg "message" "message to be output" "Hello, Juiz!"

talker :: Text -> IO Text
talker message = do
  T.putStrLn ("talker_hs: " <> message)
  -- 標準出力がファイルやパイプのときは Haskell の出力がためこまれるので、すぐに書き出す
  hFlush stdout
  pure message

juizProcess 'talker 'manifest
