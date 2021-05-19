{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Main where

import RIO
import System.Environment (getArgs)
import System.FilePath ((</>))
import qualified Data.Text as T
import qualified Data.Text.Lazy.Encoding as TL (encodeUtf8Builder)
import Network.Wai
import Network.Wai.Handler.Warp
import Network.HTTP.Types
import qualified Data.HashMap.Strict as HM
import Data.Maybe (fromMaybe)
import qualified Data.Text.Encoding as TE
import qualified Data.ByteString.Char8 as C8
import Text.Read (readMaybe)
import qualified Data.Text.IO as TIO
import System.Directory (doesFileExist)
import Control.Monad (unless, when)
import System.Environment (getArgs, getEnvironment, lookupEnv)
import qualified Data.CaseInsensitive as CI

-- From the docs here: https://kubernetes.github.io/ingress-nginx/user-guide/custom-errors/
-- X-Code          HTTP status code returned by the request
-- X-Format        Value of the Accept header sent by the client
-- X-Original-URI  URI that caused the error
-- X-Namespace     Namespace where the backend Service is located
-- X-Ingress-Name  Name of the Ingress where the backend is defined
-- X-Service-Name  Name of the Service backing the backend
-- X-Service-Port  Port number of the Service backing the backend
-- X-Request-ID    Unique ID that identifies the request - same as for backend service

-- Right now I only using the X-Code and X-Format headers to return the same code and content-type from upstream.
-- TODO: There is no check that the code or content-type are valid. But since this is to be used with the ingress-nginx I'm going to assume that it's going to be forwarding correct stuff.
-- In the future we might add more capabilities based on the rest of the headers.
main :: IO ()
main = do
  args <- getArgs
  case args of
    [port, templatesDir] -> inner 3000 templatesDir
    _ -> error "Usage: ingress-fail-page port /path/to/templatesdir"

inner :: Int -> FilePath -> IO ()
inner port templatesDir = run port $ \req send -> do
    env <- getEnvironment
    let debug = maybe False (\x -> CI.mk x == CI.mk "true") $ HM.lookup "DEBUG" $ HM.fromList env
    when debug (print req)
    case pathInfo req of
      [x] -> if x == "healthz" then send $ responseBuilder
                        status200
                        [("Content-Type", "text/html; charset=utf-8")]
                        (TL.encodeUtf8Builder "OK")
             else send $ responseBuilder
                        status404
                        [("Content-Type", "text/html; charset=utf-8")]
                        (TL.encodeUtf8Builder "default backend - 404")
      [] -> do
        let headers = HM.fromList $ requestHeaders req
        let code :: Int = maybe 200 (\s -> fromMaybe 200 $ readMaybe $ C8.unpack s) (HM.lookup "X-Code" headers)
        let exactFile = templatesDir </> ((show code) <> ".html")
        let generalFile = templatesDir </> ([(head $ show code)] <> "xx.html")
        exactFileExists <- doesFileExist exactFile
        generalFileExists <- doesFileExist generalFile
        content <- if exactFileExists then (TIO.readFile exactFile) else if generalFileExists then (TIO.readFile generalFile) else (return "default backend - 404")
        send $ responseBuilder
                  (mkStatus code "")
                  [("Content-Type", fromMaybe "text/html" $ HM.lookup "X-Format" headers)]
                  (TE.encodeUtf8Builder content)
