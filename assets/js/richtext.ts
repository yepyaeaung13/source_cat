// Native editing keeps formatting and undo available without a remote dependency.
const allowed = new Set([
  "P",
  "DIV",
  "BR",
  "H2",
  "H3",
  "STRONG",
  "B",
  "EM",
  "I",
  "U",
  "S",
  "UL",
  "OL",
  "LI",
  "BLOCKQUOTE",
  "PRE",
  "CODE",
  "A",
]);
export function cleanRichText(html: string): string {
  const source = document.createElement("template");
  source.innerHTML = html;
  function clean(node: Node): Node {
    if (node.nodeType === Node.TEXT_NODE)
      return document.createTextNode(node.textContent ?? "");
    const fragment = document.createDocumentFragment();
    if (!(node instanceof HTMLElement)) return fragment;
    if (
      [
        "SCRIPT",
        "STYLE",
        "IFRAME",
        "OBJECT",
        "SVG",
        "FORM",
        "INPUT",
        "BUTTON",
      ].includes(node.tagName)
    )
      return fragment;
    const children = [...node.childNodes].map(clean);
    if (!allowed.has(node.tagName)) {
      fragment.append(...children);
      return fragment;
    }
    const output = document.createElement(
      node.tagName === "DIV" ? "p" : node.tagName.toLowerCase(),
    );
    if (node.tagName === "A") {
      const href = node.getAttribute("href") ?? "";
      if (/^(https?:\/\/|mailto:)/i.test(href)) {
        output.setAttribute("href", href);
        output.setAttribute("rel", "noopener noreferrer");
      }
    }
    output.append(...children);
    return output;
  }
  const result = document.createElement("div");
  result.append(...[...source.content.childNodes].map(clean));
  return result.innerHTML;
}
