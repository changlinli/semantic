{-# LANGUAGE DataKinds, GeneralizedNewtypeDeriving, MultiParamTypeClasses, ScopedTypeVariables, TypeFamilies, UndecidableInstances #-}
module Analysis.CallGraph
( CallGraph(..)
, renderCallGraph
, buildCallGraph
, BuildCallGraphAlgebra(..)
) where

import qualified Algebra.Graph as G
import Algebra.Graph.Class
import Algebra.Graph.Export.Dot
import Data.Abstract.FreeVariables
import Data.Set (member)
import qualified Data.Syntax as Syntax
import qualified Data.Syntax.Declaration as Declaration
import Data.Term
import Prologue hiding (empty)

newtype CallGraph = CallGraph { unCallGraph :: G.Graph Name }
  deriving (Eq, Graph, Show)

buildCallGraph :: (BuildCallGraphAlgebra syntax, Foldable syntax, FreeVariables1 syntax, Functor syntax) => Term syntax ann -> Set Name -> CallGraph
buildCallGraph = foldSubterms buildCallGraphAlgebra


renderCallGraph :: CallGraph -> ByteString
renderCallGraph = export (defaultStyle id) . unCallGraph


-- | Types which contribute to a 'CallGraph'. There is exactly one instance of this typeclass; customizing the 'CallGraph's for a new type is done by defining an instance of 'CustomBuildCallGraphAlgebra' instead.
--
--   This typeclass employs the Advanced Overlap techniques designed by Oleg Kiselyov & Simon Peyton Jones: https://wiki.haskell.org/GHC/AdvancedOverlap.
class BuildCallGraphAlgebra syntax where
  -- | A 'SubtermAlgebra' computing the 'CallGraph' for a piece of @syntax@.
  buildCallGraphAlgebra :: FreeVariables term => syntax (Subterm term (Set Name -> CallGraph)) -> Set Name -> CallGraph

instance (BuildCallGraphAlgebraStrategy syntax ~ strategy, BuildCallGraphAlgebraWithStrategy strategy syntax) => BuildCallGraphAlgebra syntax where
  buildCallGraphAlgebra = buildCallGraphAlgebraWithStrategy (Proxy :: Proxy strategy)


-- | Types whose contribution to a 'CallGraph' is customized. If an instance’s definition is not being used, ensure that the type is mapped to 'Custom' in the 'BuildCallGraphAlgebraStrategy'.
class CustomBuildCallGraphAlgebra syntax where
  customBuildCallGraphAlgebra :: FreeVariables term => syntax (Subterm term (Set Name -> CallGraph)) -> Set Name -> CallGraph

-- | 'Declaration.Function's produce a vertex for their name, with edges to any free variables in their body.
instance CustomBuildCallGraphAlgebra Declaration.Function where
  customBuildCallGraphAlgebra Declaration.Function{..} bound = foldMap vertex (freeVariables (subterm functionName)) `connect` subtermValue functionBody (foldMap (freeVariables . subterm) functionParameters <> bound)

-- | 'Declaration.Method's produce a vertex for their name, with edges to any free variables in their body.
instance CustomBuildCallGraphAlgebra Declaration.Method where
  customBuildCallGraphAlgebra Declaration.Method{..} bound = foldMap vertex (freeVariables (subterm methodName)) `connect` subtermValue methodBody (foldMap (freeVariables . subterm) methodParameters <> bound)

-- | 'Syntax.Identifier's produce a vertex iff it’s unbound in the 'Set'.
instance CustomBuildCallGraphAlgebra Syntax.Identifier where
  customBuildCallGraphAlgebra (Syntax.Identifier name) bound
    | name `member` bound = empty
    | otherwise           = vertex name

instance Apply BuildCallGraphAlgebra syntaxes => CustomBuildCallGraphAlgebra (Union syntaxes) where
  customBuildCallGraphAlgebra = Prologue.apply (Proxy :: Proxy BuildCallGraphAlgebra) buildCallGraphAlgebra

instance BuildCallGraphAlgebra syntax => CustomBuildCallGraphAlgebra (TermF syntax a) where
  customBuildCallGraphAlgebra = buildCallGraphAlgebra . termFOut


-- | The mechanism selecting 'Default'/'Custom' implementations for 'buildCallGraphAlgebra' depending on the @syntax@ type.
class BuildCallGraphAlgebraWithStrategy (strategy :: Strategy) syntax where
  buildCallGraphAlgebraWithStrategy :: FreeVariables term => proxy strategy -> syntax (Subterm term (Set Name -> CallGraph)) -> Set Name -> CallGraph

-- | The 'Default' definition of 'buildCallGraphAlgebra' combines all of the 'CallGraph's within the @syntax@ 'Monoid'ally.
instance Foldable syntax => BuildCallGraphAlgebraWithStrategy 'Default syntax where
  buildCallGraphAlgebraWithStrategy _ = foldMap subtermValue

-- | The 'Custom' strategy calls out to the 'customBuildCallGraphAlgebra' method.
instance CustomBuildCallGraphAlgebra syntax => BuildCallGraphAlgebraWithStrategy 'Custom syntax where
  buildCallGraphAlgebraWithStrategy _ = customBuildCallGraphAlgebra

data Strategy = Default | Custom

type family BuildCallGraphAlgebraStrategy syntax where
  BuildCallGraphAlgebraStrategy Declaration.Function = 'Custom
  BuildCallGraphAlgebraStrategy Declaration.Method = 'Custom
  BuildCallGraphAlgebraStrategy Syntax.Identifier = 'Custom
  BuildCallGraphAlgebraStrategy (Union fs) = 'Custom
  BuildCallGraphAlgebraStrategy (TermF f a) = 'Custom
  BuildCallGraphAlgebraStrategy a = 'Default


instance Monoid CallGraph where
  mempty = empty
  mappend = overlay

instance Ord CallGraph where
  compare (CallGraph G.Empty)           (CallGraph G.Empty)           = EQ
  compare (CallGraph G.Empty)           _                             = LT
  compare _                             (CallGraph G.Empty)           = GT
  compare (CallGraph (G.Vertex a))      (CallGraph (G.Vertex b))      = compare a b
  compare (CallGraph (G.Vertex _))      _                             = LT
  compare _                             (CallGraph (G.Vertex _))      = GT
  compare (CallGraph (G.Overlay a1 a2)) (CallGraph (G.Overlay b1 b2)) = (compare `on` CallGraph) a1 b1 <> (compare `on` CallGraph) a2 b2
  compare (CallGraph (G.Overlay _  _))  _                             = LT
  compare _                             (CallGraph (G.Overlay _ _))   = GT
  compare (CallGraph (G.Connect a1 a2)) (CallGraph (G.Connect b1 b2)) = (compare `on` CallGraph) a1 b1 <> (compare `on` CallGraph) a2 b2
