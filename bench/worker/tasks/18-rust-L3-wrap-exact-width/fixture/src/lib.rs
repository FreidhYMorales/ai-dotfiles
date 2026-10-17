//! Greedy word wrapping for terminal help text.

/// Wrap `text` into lines of at most `width` characters, breaking only at
/// whitespace. Runs of whitespace (including newlines) collapse to one space.
/// A word longer than `width` gets a line of its own and is not split.
/// Returns no lines for text without words. `width` 0 is treated as 1.
pub fn wrap(text: &str, width: usize) -> Vec<String> {
    let width = width.max(1);
    let mut lines = Vec::new();
    let mut line = String::new();
    for word in text.split_whitespace() {
        if line.is_empty() {
            line.push_str(word);
        } else if line.len() + 1 + word.len() < width {
            line.push(' ');
            line.push_str(word);
        } else {
            lines.push(std::mem::take(&mut line));
            line.push_str(word);
        }
    }
    if !line.is_empty() {
        lines.push(line);
    }
    lines
}

/// `wrap` joined with newlines, each line prefixed with `indent`.
pub fn fill(text: &str, width: usize, indent: &str) -> String {
    wrap(text, width.saturating_sub(indent.len()))
        .iter()
        .map(|l| format!("{indent}{l}"))
        .collect::<Vec<_>>()
        .join("\n")
}
