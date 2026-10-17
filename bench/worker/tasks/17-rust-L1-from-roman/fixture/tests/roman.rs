use roman::{to_roman, MAX};

#[test]
fn small_numbers() {
    assert_eq!(to_roman(1).as_deref(), Some("I"));
    assert_eq!(to_roman(4).as_deref(), Some("IV"));
    assert_eq!(to_roman(9).as_deref(), Some("IX"));
    assert_eq!(to_roman(14).as_deref(), Some("XIV"));
}

#[test]
fn large_numbers() {
    assert_eq!(to_roman(1994).as_deref(), Some("MCMXCIV"));
    assert_eq!(to_roman(MAX).as_deref(), Some("MMMCMXCIX"));
}

#[test]
fn out_of_range() {
    assert_eq!(to_roman(0), None);
    assert_eq!(to_roman(MAX + 1), None);
}
