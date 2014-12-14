module QuickSpec.Pruning.Rewrite where

import QuickSpec.Base
import QuickSpec.Pruning.Constraints
import qualified QuickSpec.Pruning.Index as Index
import QuickSpec.Pruning.Index(Index)
import QuickSpec.Pruning.Queue
import QuickSpec.Term
import Control.Monad
import Data.Maybe
import Data.Rewriting.Rule
import Debug.Trace

type Strategy f v = Tm f v -> [Tm f v]

normaliseWith :: (PrettyTerm f, Pretty v) => Strategy f v -> Tm f v -> Tm f v
normaliseWith strat t =
  case strat t of
    [] -> t
    (u:_) -> normaliseWith strat u

anywhere :: Strategy f v -> Strategy f v
anywhere strat t = strat t ++ nested (anywhere strat) t

nested :: Strategy f v -> Strategy f v
nested strat Var{} = []
nested strat (Fun f xs) = map (Fun f) (combine xs (map strat xs))
  where
    combine [] [] = []
    combine (x:xs) (ys:yss) =
      [ y:xs | y <- ys ] ++ [ x:zs | zs <- combine xs yss ]

ordered :: (Sized f, Ord f, Ord v) => Strategy f v -> Strategy f v
ordered strat t = [u | u <- strat t, u `simplerThan` t]

tryRule :: (PrettyTerm f, Pretty v, Sized f, Ord f, Ord v, Numbered v) => Context f v -> Constrained (Rule f v) -> Strategy f v
tryRule ctx rule t = do
  sub <- maybeToList (match (lhs (constrained rule)) t)
  let rule' = substf (evalSubst sub) rule
  guard (implies (solved ctx) (runM simplify (formula (context rule'))))
  return (rhs (constrained rule'))

tryRules :: (PrettyTerm f, Pretty v, Sized f, Ord f, Ord v, Numbered v) => Context f v -> Index (Labelled (Constrained (Rule f v))) -> Strategy f v
tryRules ctx rules t = do
  rule <- map peel (Index.lookup t rules)
  guard (implies (solved ctx) (runM simplify (formula (context rule))))
  -- traceM (show (hang (pretty rule <+> text "in context") 2 (pretty ctx)))
  return (rhs (constrained rule))
