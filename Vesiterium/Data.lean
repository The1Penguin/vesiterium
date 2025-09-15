def Byte :=  { n : Nat // n ≤ 255 }

def Word := { n : Nat // n ≤ 65535 }

structure Pair (A : Type u) (B : Type v) where
   fst : A
   snd : B

theorem mul_le_self {a b c : Nat} (p : a ≤ b) : a * c ≤ b * c := Nat.mul_le_mul p (.refl)

theorem WordDivision256 { v : Word } : v.val / 256 ≤ 255 :=
  let ⟨ val, p ⟩ := v
  (Nat.div_le_iff_le_mul (k := 256) (x := val) (y := 255) (by decide)).mpr p

theorem mod_succ_le {a b : Nat} : (a % b.succ) ≤ b :=
  Nat.lt_succ.mp (Nat.mod_lt a (Nat.zero_lt_succ b) )

def PairByteToWord : Pair Byte Byte → Word
  | .mk ⟨v₁, p₁⟩ ⟨v₂, p₂⟩ => ⟨ (v₁ * 256) + v₂, Nat.add_le_add (mul_le_self p₁) p₂ ⟩

def WordToPairByte : Word → Pair Byte Byte
  | w@(⟨ v, _⟩) => .mk
    ⟨ w.val / 256 , WordDivision256 ⟩
    ⟨ v % 256 , mod_succ_le ⟩

theorem WordToPairByte_inverse {w : Word} : (PairByteToWord ∘ WordToPairByte) w = w := by
  have ⟨ v , p ⟩ := w
  simp [WordToPairByte, PairByteToWord, Nat.mul_comm, Nat.div_add_mod]

theorem not_le_self_mod {a b : Nat} (h : b > 0) : ¬ b ≤ a % b := by
  simp [Nat.mod_lt a h]

theorem PairByteToWord_inverse (p : Pair Byte Byte) : (WordToPairByte ∘ PairByteToWord) p = p := by
  have .mk ⟨v₁, p₁⟩ ⟨v₂, p₂⟩ := p
  simp
    [ PairByteToWord
    , WordToPairByte
    , Nat.add_div
    , Nat.div_eq_of_lt (Nat.lt_succ.mpr p₂)
    , if_neg (not_le_self_mod (a := v₂) (b := 256) (by decide))
    ]
  simp [ Nat.mod_eq_of_lt (Nat.lt_succ.mpr p₂) ]
