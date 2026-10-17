use wrap::{fill, wrap};

#[test]
fn exact_width_fits() {
    assert_eq!(wrap("hello world", 11), vec!["hello world"]);
    assert_eq!(wrap("ab cd ef", 5), vec!["ab cd", "ef"]);
    assert_eq!(wrap("a b c d", 3), vec!["a b", "c d"]);
    assert_eq!(wrap("a b", 1), vec!["a", "b"]);
}

#[test]
fn one_over_still_breaks() {
    assert_eq!(wrap("hello world", 10), vec!["hello", "world"]);
    assert_eq!(wrap("ab cd ef", 4), vec!["ab", "cd", "ef"]);
}

#[test]
fn no_line_exceeds_width_and_lines_are_full() {
    let text = "lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod \
                tempor incididunt ut labore et dolore magna aliqua";
    let words: Vec<&str> = text.split_whitespace().collect();
    for width in 6..40 {
        let lines = wrap(text, width);
        assert_eq!(lines.join(" ").split(' ').collect::<Vec<_>>(), words, "width {width}");
        for (i, l) in lines.iter().enumerate() {
            assert!(l.len() <= width || !l.contains(' '), "width {width}: {l:?} too long");
            if let Some(next) = lines.get(i + 1) {
                let first = next.split(' ').next().unwrap();
                assert!(l.len() + 1 + first.len() > width, "width {width}: {first:?} fits on {l:?}");
            }
        }
    }
}

#[test]
fn documented_behavior_kept() {
    assert_eq!(wrap("a supercalifragilistic b", 5), vec!["a", "supercalifragilistic", "b"]);
    assert_eq!(wrap("  a \n\n b\t c  ", 5), vec!["a b c"]);
    assert!(wrap("", 10).is_empty());
    assert_eq!(wrap("a b", 0), vec!["a", "b"]);
    assert_eq!(fill("one two three", 9, "  "), "  one two\n  three");
}
