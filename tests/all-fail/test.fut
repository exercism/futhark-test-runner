import "all_fail"

-- Year not divisible by 4 in common year
-- ==
-- input { 2015 }
-- output { false }

-- Year divisible by 4 and 5 is still a leap year
-- ==
-- input { 1960 }
-- output { true }

-- Year divisible by 100, not divisible by 400 in common year
-- ==
-- input { 2100 }
-- output { false }

let main (year: i32): bool =
  is_leap year
