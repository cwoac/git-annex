{- git-annex tagged pushes
 -
 - Copyright 2012 Joey Hess <joey@kitenet.net>
 -
 - Licensed under the GNU GPL version 3 or higher.
 -}

module Annex.TaggedPush where

import Common.Annex
import qualified Remote
import qualified Annex.Branch
import qualified Git
import qualified Git.Ref
import qualified Git.Command
import Utility.Base64

{- Converts a git branch into a branch that is tagged with a UUID, typically
 - the UUID of the repo that will be pushing it, and possibly with other
 - information.
 -
 - Pushing to branches on the remote that have out uuid in them is ugly,
 - but it reserves those branches for pushing by us, and so our pushes will
 - never conflict with other pushes.
 -
 - To avoid cluttering up the branch display, the branch is put under
 - refs/synced/, rather than the usual refs/remotes/
 -
 - Both UUIDs and Base64 encoded data are always legal to be used in git
 - refs, per git-check-ref-format.
 -}
toTaggedBranch :: UUID -> Maybe String -> Git.Branch -> Git.Branch
toTaggedBranch u info b = Git.Ref $ intercalate "/" $ catMaybes
	[ Just "refs/synced"
	, Just $ fromUUID u
	, toB64 <$> info
	, Just $ show $ Git.Ref.base b
	]

fromTaggedBranch :: Git.Branch -> Maybe (UUID, Maybe String)
fromTaggedBranch b = case split "/" $ show b of
	("refs":"synced":u:info:_base) ->
		Just (toUUID u, fromB64Maybe info)
	("refs":"synced":u:_base) ->
		Just (toUUID u, Nothing)
	_ -> Nothing
  where

taggedPush :: UUID -> Maybe String -> Git.Ref -> Remote -> Git.Repo -> IO Bool
taggedPush u info branch remote = Git.Command.runBool
        [ Param "push"
        , Param $ Remote.name remote
        , Param $ refspec Annex.Branch.name
        , Param $ refspec branch
        ]
  where
	refspec b = show b ++ ":" ++ show (toTaggedBranch u info b)
