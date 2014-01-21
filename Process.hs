module Solver
    ( beginProcess
    , send
    , endProcess
    , z3
    , cvc4
    ) where

import System.Process
import GHC.IO.Handle
import Data.Maybe
import Semantics

type CmdPath = String
type Args = [String] 

--Type returned by CreateProcess
type Process = 
    ( Maybe Handle -- process std_in pipe
    , Maybe Handle -- process std_out pipe
    , Maybe Handle -- process std_err pipe
    , ProcessHandle -- process pid
    )

{- Generates a CreateProcess 
 -with just the command,
 -the arguments
 -and creates the pipes to comunicate
 -}
newProcess :: CmdPath -> Args -> CreateProcess
newProcess p a = CreateProcess
    { cmdspec = RawCommand p a
    , cwd = Nothing
    , env = Nothing
    , std_in = CreatePipe
    , std_out = CreatePipe
    , std_err = CreatePipe
    , close_fds = False
    , create_group =  False 
	  }
	  

-- Creates a Process ready to be executed
beginProcess :: CmdPath -> Args -> (IO Process)
beginProcess cmd path  = createProcess (newProcess cmd path)

--Simpler interface for readResponse'
readResponse :: Handle -> IO String
readResponse = readResponse' "" True

--Reads the answer from the process on std_out
readResponse' :: String ->Bool -> Handle ->IO String
readResponse' str False _ = return str
readResponse' str True handle = do
                  text <- hGetLine handle
                  has_more <-hWaitForInput handle 2
                  readResponse' (str++text) has_more handle
            
--Sends the desired input to the process and returns the anwser if there is any
send :: Process -> String -> IO String
send (Just std_in, Just std_out,_,_) cmd = do
  hPutStr std_in cmd 
  hFlush std_in 
  readResponse std_out

--Test method to test if cvc4 printed to std_err
send' :: Process -> String -> IO String
send' (Just std_in, Just std_out,Just std_err,_) cmd = do
  hPutStr std_in cmd 
  hFlush std_in 
  --readResponse std_err Throws Exception
  hGetLine std_err
 
--Sends the signal to terminate to the running process
endProcess :: Process -> IO()
endProcess (_,_,_,processHandle) = do
  terminateProcess processHandle
  waitForProcess processHandle >>= print
--{
-- z3 seems to work fine
-- cvc4 does not, if it dosn't like some input,it prints to std_err,
-- and hWaitForInput is throwing EOF, we have to catch it.
-- cvc4 isn't full smt-lib v2 compliant
--}  

z3 :: IO()
z3 = do
  smt <- beginProcess "z3" ["-smt2","-in"]
  send smt "(set-option :print-success true)\n" >>= print
  send smt "(declare-const a Int)\n" >>= print
  send smt "(declare-fun f (Int Bool) Int)\n" >>= print  
  send smt "(assert (> a 10))\n" >>= print
  send smt "(assert (< (f a true) 100))\n" >>= print
  send smt "(check-sat)\n" >>= print
  send smt "(get-model)\n" >>= print
  endProcess smt
  
cvc4 :: IO()
cvc4 = do
  smt <- beginProcess "cvc4" ["--smtlib-strict"]
  send smt "(set-option :print-success true)\n" >>= print
  --CVC4 wont accept the next command and print the warning to std_err 
  send' smt "(declare-const a Int)\n" >>= print 
  send' smt "(declare-fun f (Int Bool) Int)\n" >>= print  
  send' smt "(assert (> a 10))\n" >>= print
  send' smt "(assert (< (f a true) 100))\n" >>= print
  --send' smt "(check-sat)\n" >>= print
  --send' smt "(get-model)\n" >>= print
  endProcess smt  
