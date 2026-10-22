{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
-- | 受け取った文字列を表示する Process (listener_hs)。
module Listener () where

import qualified Data.Text.IO as T
import System.IO (hFlush, stdout)

import Juiz

manifest :: ProcessManifest
manifest = processManifest "listener_hs"
  & description "Prints the received message."
  & addStringArg "arg1" "message to be printed" "Hello, Juiz!"

listener :: Text -> IO Text
listener arg1 = do
  T.putStrLn ("listener_hs: " <> arg1)
  hFlush stdout
  pure arg1

juizProcess 'listener 'manifest
