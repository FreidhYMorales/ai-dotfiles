use wrap::{fill, wrap};

#[test]
fn short_text_is_one_line() {
    assert_eq!(wrap("hello world", 20), vec!["hello world"]);
}

#[test]
fn breaks_between_words() {
    assert_eq!(
        wrap("the quick brown fox jumps", 12),
        vec!["the quick", "brown fox", "jumps"]
    );
}

#[test]
fn collapses_whitespace() {
    assert_eq!(wrap("  a \n\n b\t c  ", 20), vec!["a b c"]);
}

#[test]
fn long_word_gets_its_own_line() {
    assert_eq!(wrap("a supercalifragilistic b", 5), vec!["a", "supercalifragilistic", "b"]);
}

#[test]
fn empty_text() {
    assert!(wrap("   ", 10).is_empty());
}

#[test]
fn fill_indents() {
    assert_eq!(fill("one two three", 10, "  "), "  one two\n  three");
}
