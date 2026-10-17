"""Slug generation."""

import re
import unicodedata

_NON_ALNUM = re.compile(r"[^a-z0-9]+")


def slugify(text, sep="-"):
    """Return an ASCII slug for text.

    Accents are stripped ("é" becomes "e"), letters are lowercased and every
    run of other characters becomes a single `sep`, never at either end.
    """
    if not isinstance(text, str):
        raise TypeError("text must be a str")
    ascii_text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    words = _NON_ALNUM.split(ascii_text.lower())
    return sep.join(w for w in words if w)
