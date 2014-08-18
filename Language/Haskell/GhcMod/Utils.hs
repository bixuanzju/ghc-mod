module Language.Haskell.GhcMod.Utils where


import MonadUtils (MonadIO, liftIO)
import Control.Exception
import Control.Monad.Error (MonadError(..), Error(..))
import System.Directory (getCurrentDirectory, setCurrentDirectory)
import System.Process (readProcessWithExitCode)
import System.Exit (ExitCode(..))
import System.IO (hPutStrLn, stderr)
import System.IO.Error (tryIOError)


-- dropWhileEnd is not provided prior to base 4.5.0.0.
dropWhileEnd :: (a -> Bool) -> [a] -> [a]
dropWhileEnd p = foldr (\x xs -> if p x && null xs then [] else x : xs) []

extractParens :: String -> String
extractParens str = extractParens' str 0
 where
   extractParens' :: String -> Int -> String
   extractParens' [] _ = []
   extractParens' (s:ss) level
       | s `elem` "([{" = s : extractParens' ss (level+1)
       | level == 0 = extractParens' ss 0
       | s `elem` "}])" && level == 1 = [s]
       | s `elem` "}])" = s : extractParens' ss (level-1)
       | otherwise = s : extractParens' ss level

readProcess' :: (MonadIO m, Error e, MonadError e m)
             => String
             -> [String]
             -> m String
readProcess' cmd opts = do
  (rv,output,err) <- liftIO $ readProcessWithExitCode cmd opts ""
  case rv of
    ExitFailure val -> do
        liftIO $ hPutStrLn stderr err
        throwError $ strMsg $
          cmd ++ " " ++ unwords opts ++ " (exit " ++ show val ++ ")"
    ExitSuccess ->
        return output

withDirectory_ :: FilePath -> IO a -> IO a
withDirectory_ dir action =
    bracket getCurrentDirectory setCurrentDirectory
                (\_ -> setCurrentDirectory dir >> action)

rethrowError :: MonadError e m => (e -> e) -> m a -> m a
rethrowError f action = action `catchError` \e -> throwError $ f e

tryFix :: MonadError e m => m a -> (e -> m ()) -> m a
tryFix action fix = do
  action `catchError` \e -> fix e >> action

liftMonadError :: (MonadIO m, Error e, MonadError e m) => IO a -> m a
liftMonadError action = do
  res <- liftIO $ tryIOError action
  case res of
    Right a -> return a
    Left e -> case show e of
                ""  -> throwError $ noMsg
                msg -> throwError $ strMsg msg
