def Byte :=  { n : Nat // n ≤ 255 }

def Word := { n : Nat // n ≤ 65535 }

structure Pair (A : Type u) (B : Type v) where
   fst : A
   snd : B

theorem mul_le_self (a b c : Nat) (p : a ≤ b) : a * c ≤ b * c := Nat.mul_le_mul p (.refl)

def pairByteToWord : Pair Byte Byte → Word
  | .mk ⟨v₁, p₁⟩ ⟨v₂, p₂⟩ => ⟨ (v₁ * 256) + v₂, Nat.add_le_add (mul_le_self v₁ 255 256 p₁) p₂ ⟩
