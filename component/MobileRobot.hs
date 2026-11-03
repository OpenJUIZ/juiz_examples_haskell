{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
-- | Transformations のサンプル: 台車 → 雲台 → カメラ の部品 (mobile_robot_hs、OpenJUIZ/juiz#374)。
--
-- 位置姿勢 (ContainerPose) は juiz が Container ごとに持ち、利用者の状態とは別にある。
-- 部品のつながり (Transform) と基点 (Anchor) は transformations.conf に書く:
--
-- > map (Periodic) → odom (Static) → base0 (mobile_base_hs) → pantilt0 (pantilt_hs) → camera0 (camera_hs)
--
-- * mobile_base_hs_move はオドメトリを積分して、odom から見た自分の位置姿勢を setContainerPose で書く。
-- * pantilt_hs_set_pan はパン角を書く (台車から見た自分の向きだけを変える)。
-- * camera_hs_pose は基準から見た自分の位置姿勢を containerPose で読む。カメラは Transform で雲台につながっているだけ。
-- * pose_print_hs は Pose 通知 (conf の pose_listeners:) で呼ばれる Process。
--
-- ContainerProcess の関数は Container の状態だけを受け取り、containerPose / setContainerPose は
-- 「今呼ばれている ContainerProcess の Container」を読み書きする。
module MobileRobot () where

import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import qualified Data.Text.IO as T
import System.IO (hFlush, stdout)
import Text.Printf (printf)

import Juiz

component :: ComponentManifest
component = componentManifest "mobile_robot_hs"
  & description "Parts of a mobile robot (base, pan-tilt and camera) for Transformations."

-- | z 軸まわりに yaw [rad] 回す姿勢で、位置 (x, y, z) の ContainerPose を作る
yawPose :: (Double, Double, Double) -> Double -> ContainerPose
yawPose position yaw = ContainerPose position (0, 0, sin (yaw / 2), cos (yaw / 2))

-- | 台車。オドメトリ (odom から見た x, y, 向き theta) を自分で積分して持つ
newtype MobileBase = MobileBase (IORef (Double, Double, Double))

mobileBaseManifest :: ContainerManifest
mobileBaseManifest = containerManifest "mobile_base_hs"
  & description "Mobile base. Integrates its odometry."

createMobileBase :: IO MobileBase
createMobileBase = MobileBase <$> newIORef (0, 0, 0)

-- | 速度 vx [m/s]・角速度 omega [rad/s] で dt [s] 動かし、基準 reference (odom) から見た位置姿勢を書く
moveManifest :: ProcessManifest
moveManifest = containerProcessManifest "mobile_base_hs_move" "mobile_base_hs"
  & addFloatArg "vx" "velocity [m/s]" 0
  & addFloatArg "omega" "angular velocity [rad/s]" 0
  & addFloatArg "dt" "time step [s]" 1
  & addStringArg "reference" "reference container" "odom"

move :: MobileBase -> Double -> Double -> Double -> Text -> IO Value
move (MobileBase ref) vx omega dt reference = do
  (x, y, theta) <- readIORef ref
  let x' = x + vx * cos theta * dt
      y' = y + vx * sin theta * dt
      theta' = theta + omega * dt
  writeIORef ref (x', y', theta')
  -- odom → base0 の Transform が書き換わり、Pose 通知が出る
  poseStampedToValue reference <$> setContainerPose reference (yawPose (x', y', 0) theta')

-- | 雲台。パン角を持つ
newtype Pantilt = Pantilt (IORef Double)

pantiltManifest :: ContainerManifest
pantiltManifest = containerManifest "pantilt_hs"
  & description "Pan-tilt unit. Holds its pan angle."

createPantilt :: IO Pantilt
createPantilt = Pantilt <$> newIORef 0

-- | パン角 pan [rad] にする。取り付け位置はそのままで、基準 reference (台車) から見た向きだけを変える
setPanManifest :: ProcessManifest
setPanManifest = containerProcessManifest "pantilt_hs_set_pan" "pantilt_hs"
  & addFloatArg "pan" "pan angle [rad]" 0
  & addStringArg "reference" "reference container" "base0"

setPan :: Pantilt -> Double -> Text -> IO Value
setPan (Pantilt ref) pan reference = do
  writeIORef ref pan
  (ContainerPose mount _, _) <- containerPose reference
  poseStampedToValue reference <$> setContainerPose reference (yawPose mount pan)

-- | カメラ。利用者の状態は持たない
data Camera = Camera

cameraManifest :: ContainerManifest
cameraManifest = containerManifest "camera_hs"
  & description "Camera. Attached to the pan-tilt unit by a Transform."

createCamera :: IO Camera
createCamera = pure Camera

-- | 基準 reference から見た自分の位置姿勢 (juiz_std.geometry.PoseStamped の辞書)
cameraPoseManifest :: ProcessManifest
cameraPoseManifest = containerProcessManifest "camera_hs_pose" "camera_hs"
  & addStringArg "reference" "reference container" "map"

cameraPose :: Camera -> Text -> IO Value
cameraPose Camera reference = poseStampedToValue reference <$> containerPose reference

-- | Pose 通知の受け手。受け取った位置姿勢 (juiz_std.geometry.PoseStamped の辞書) を表示する
posePrintManifest :: ProcessManifest
posePrintManifest = processManifest "pose_print_hs"
  & description "Prints the received ContainerPose."
  & addObjectArg "pose" "juiz_std.geometry.PoseStamped" []

posePrint :: Value -> IO Text
posePrint pose = do
  let at path = foldl (\v k -> case v of JObject m -> Map.findWithDefault JNull k m; _ -> JNull) pose path
      num v = case v of JFloat d -> d; JInt i -> fromIntegral i; JUInt u -> fromIntegral u; _ -> 0
      position k = num (at ["pose", "position", k])
      q k = num (at ["pose", "orientation", k])
      yaw = atan2 (2 * (q "w" * q "z" + q "x" * q "y")) (1 - 2 * (q "y" * q "y" + q "z" * q "z"))
      frameId = case at ["header", "frame_id"] of JString s -> s; _ -> ""
      text = T.pack (printf "pose_print_hs: x=%.2f y=%.2f yaw=%.1fdeg (from %s)"
                       (position "x") (position "y") (yaw * 180 / pi) (T.unpack frameId))
  T.putStrLn text
  hFlush stdout
  pure text

juizComponent 'component
  [ componentProcess 'posePrint 'posePrintManifest
  , componentContainer 'createMobileBase 'mobileBaseManifest
  , componentContainerProcess 'move 'moveManifest
  , componentContainer 'createPantilt 'pantiltManifest
  , componentContainerProcess 'setPan 'setPanManifest
  , componentContainer 'createCamera 'cameraManifest
  , componentContainerProcess 'cameraPose 'cameraPoseManifest
  ]
