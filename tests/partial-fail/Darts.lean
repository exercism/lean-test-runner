namespace Darts

def distance (x : Float) (y : Float) : Float :=
  Float.sqrt (x ^ 2 + y ^ 2)

-- Partially correct: gets outer ring right but everything else wrong
def score (x : Float) (y : Float) : Int :=
  let dist := distance x y
  if dist > 10.0 then 0
  else 1  -- Returns 1 for everything inside the target

end Darts
