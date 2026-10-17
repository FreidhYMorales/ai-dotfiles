use roman::{from_roman, to_roman, MAX};

#[test]
fn round_trips_every_number() {
    for n in 1..=MAX {
        let s = to_roman(n).unwrap();
        assert_eq!(from_roman(&s), Some(n), "{s}");
    }
}

#[test]
fn known_values() {
    assert_eq!(from_roman("MCMXCIV"), Some(1994));
    assert_eq!(from_roman("MMMCMXCIX"), Some(3999));
    assert_eq!(from_roman("XLII"), Some(42));
}

#[test]
fn rejects_non_canonical() {
    for bad in [
        "", "IIII", "VV", "IC", "XM", "IIV", "VX", "LL", "DD", "CCCC", "MMMM", "XXXX", "IL", "VL",
        "LC", "DM", "IXI", "XCX", "CMC", "IVI", "MMMCMXCX", "IIX",
    ] {
        assert_eq!(from_roman(bad), None, "{bad:?} should be rejected");
    }
}

#[test]
fn rejects_other_text() {
    for bad in ["iv", "Iv", " X", "X ", "X1", "ABC", "MMMCMXCIXI", "\u{216B}"] {
        assert_eq!(from_roman(bad), None, "{bad:?} should be rejected");
    }
}
