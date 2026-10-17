//! Roman numerals (standard subtractive form, 1 to 3999).

const NUMERALS: [(u32, &str); 13] = [
    (1000, "M"),
    (900, "CM"),
    (500, "D"),
    (400, "CD"),
    (100, "C"),
    (90, "XC"),
    (50, "L"),
    (40, "XL"),
    (10, "X"),
    (9, "IX"),
    (5, "V"),
    (4, "IV"),
    (1, "I"),
];

/// Largest number a standard numeral can express.
pub const MAX: u32 = 3999;

/// `n` as an uppercase Roman numeral, or `None` outside 1..=3999.
pub fn to_roman(n: u32) -> Option<String> {
    if n == 0 || n > MAX {
        return None;
    }
    let mut rest = n;
    let mut out = String::new();
    for &(value, symbol) in NUMERALS.iter() {
        while rest >= value {
            out.push_str(symbol);
            rest -= value;
        }
    }
    Some(out)
}
