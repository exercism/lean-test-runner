namespace Lasagna

def expectedMinutesInOven : Nat :=
  40

def remainingMinutesInOven (actualMinutesInOven : Nat) : Nat :=
  expectedMinutesInOven - actualMinutesInOven

end Lasagna
