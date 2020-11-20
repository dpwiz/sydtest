module Test.Syd.Silence where

import Data.Compact
import Data.Compact.Serialize
import Data.Typeable
import System.Exit
import System.IO.Error
import System.Posix.Files
import System.Posix.IO
import System.Posix.Process
import System.Posix.Signals
import System.Posix.Types
import UnliftIO
import UnliftIO.Resource

runInSilencedProcess :: (Typeable a, MonadUnliftIO m) => ResourceT m a -> ResourceT m a
runInSilencedProcess func = do
  (pipeReadFd, pipeWriteFd) <- liftIO createPipe
  pipeReadHandle <- liftIO $ fdToHandle pipeReadFd
  pipeWriteHandle <- liftIO $ fdToHandle pipeWriteFd
  runInIO <- askRunInIO
  let runChild :: IO ()
      runChild = do
        -- Don't input or output anything
        newStdin <- createFile "/dev/null" ownerModes
        _ <- dupTo newStdin stdInput
        newStdout <- createFile "/dev/null" ownerModes
        _ <- dupTo newStdout stdOutput
        newStderr <- createFile "/dev/null" ownerModes
        _ <- dupTo newStderr stdError
        -- Actually run the function
        result <- runInIO func
        compactRegion <- compact result
        hPutCompact pipeWriteHandle compactRegion
        hFlush pipeWriteHandle
        hClose pipeWriteHandle
      cleanupProcess :: ProcessID -> IO ()
      cleanupProcess pid = do
        mps <-
          catchJust
            (\ioerr -> if isDoesNotExistError ioerr then Just ioerr else Nothing)
            (Just <$> getProcessStatus False False pid)
            (\_ -> pure Nothing)
        case mps of
          Nothing -> pure () -- No process found
          Just Nothing -> signalProcess sigTERM pid
          Just (Just _) -> pure () -- Already taken care of.
  (_, testProcess) <- allocate (forkProcess runChild) cleanupProcess
  liftIO $ print "waiting for process to finish"
  -- Wait for the testing process to finish
  mf <- liftIO $ getProcessStatus True False testProcess
  liftIO $ print $ case mf of
    Nothing -> "going on, but not finished"
    Just _ -> "process finished"
  -- Read its result from the pipe
  errOrResult <- liftIO $ hUnsafeGetCompact pipeReadHandle
  case errOrResult of
    Left err -> liftIO $ die err -- This means something went wrong with the compact region
    Right compactRegion -> pure $ getCompact compactRegion
