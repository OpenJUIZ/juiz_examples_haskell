{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
-- | 姿勢 pose から速度 twist で dt 秒動いた姿勢を返す Process (pose_move_hs)。
--
-- 引数と戻り値が型付き (examples.geometry の Pose2D・Twist2D) なので、型の合わない Process とは接続できない。
-- 型は build.sh が types/geometry.jidl から juiz-idl -g haskell で build/gen-hs に作る (Examples.Geometry)。
module PoseMove () where

import System.IO (hFlush, stdout)
import Text.Printf (printf)

import Juiz

import Examples.Geometry

-- 型付きの引数の既定値は型の値で書く (defaultPose2D は全フィールドが既定値)。
-- 結果が型付きの型なので、戻り値の型 (output_schema) は書かなくても載る
manifest :: ProcessManifest
manifest = processManifest "pose_move_hs"
  & description "Moves the pose by the twist for dt seconds."
  & addTypedArg "pose" "current pose" defaultPose2D
  & addTypedArg "twist" "velocity" defaultTwist2D
  & addFloatArg "dt" "duration [s]" 1

poseMove :: Pose2D -> Twist2D -> Double -> IO Pose2D
poseMove pose twist dt = do
  let Point2D x y = pose2DPosition pose
      theta = pose2DTheta pose
      distance = twist2DLinear twist * dt
      moved = pose
        { pose2DPosition = Point2D (x + distance * cos theta) (y + distance * sin theta)
        , pose2DTheta = theta + twist2DAngular twist * dt
        }
      Point2D x' y' = pose2DPosition moved
  printf "pose_move_hs: (%.2f, %.2f, %.2f) -> (%.2f, %.2f, %.2f)\n" x y theta x' y' (pose2DTheta moved)
  hFlush stdout
  pure moved

juizProcess 'poseMove 'manifest
