import React, { useEffect, useRef } from "react";
import {
  Bold,
  Italic,
  Heading2,
  Heading3,
  List,
  ListOrdered,
  Quote,
  Code,
  ExternalLink,
  Unlink,
  Undo2,
  Redo2,
  Pilcrow,
} from "lucide-react";
import { cleanRichText } from "../richtext";
export function RichEditor({
  value,
  onChange,
}: {
  value: string;
  onChange: (html: string) => void;
}) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (ref.current && ref.current.innerHTML !== value)
      ref.current.innerHTML = value;
  }, [value]);
  function command(cmd: string, arg?: string) {
    ref.current?.focus();
    if (cmd === "link") {
      const href = window.prompt("Link URL (https://…)");
      if (!href) return;
      if (!/^https?:\/\//i.test(href)) return;
      document.execCommand("createLink", false, href);
    } else if (cmd === "code") {
      const pre = document.createElement("pre");
      const code = document.createElement("code");
      code.textContent = window.getSelection()?.toString() || "Your code here";
      pre.append(code);
      document.execCommand("insertHTML", false, pre.outerHTML + "<p><br></p>");
    } else document.execCommand(cmd, false, arg);
    if (ref.current) onChange(cleanRichText(ref.current.innerHTML));
  }
  const tools = [
    { name: "Paragraph", cmd: "formatBlock", arg: "p", icon: Pilcrow },
    { name: "Bold", cmd: "bold", icon: Bold },
    { name: "Italic", cmd: "italic", icon: Italic },
    { name: "Heading 2", cmd: "formatBlock", arg: "h2", icon: Heading2 },
    { name: "Heading 3", cmd: "formatBlock", arg: "h3", icon: Heading3 },
    { name: "Bullet list", cmd: "insertUnorderedList", icon: List },
    { name: "Numbered list", cmd: "insertOrderedList", icon: ListOrdered },
    { name: "Quote", cmd: "formatBlock", arg: "blockquote", icon: Quote },
    { name: "Code block", cmd: "code", icon: Code },
    { name: "Insert link", cmd: "link", icon: ExternalLink },
    { name: "Remove link", cmd: "unlink", icon: Unlink },
    { name: "Undo", cmd: "undo", icon: Undo2 },
    { name: "Redo", cmd: "redo", icon: Redo2 },
  ];
  return (
    <div className="rich-editor">
      <div className="rich-toolbar" role="toolbar" aria-label="Formatting">
        {tools.map((t) => (
          <button
            key={t.name}
            type="button"
            title={t.name}
            aria-label={t.name}
            onMouseDown={(e) => e.preventDefault()}
            onClick={() => command(t.cmd, t.arg)}
          >
            <t.icon />
          </button>
        ))}
      </div>
      <div
        id="post-rich-editor"
        ref={ref}
        role="textbox"
        aria-label="Post description"
        aria-multiline="true"
        contentEditable
        suppressContentEditableWarning
        className="rich-surface prose"
        data-placeholder="Write your post…"
        onInput={(e) => onChange(cleanRichText(e.currentTarget.innerHTML))}
        onPaste={(e) => {
          e.preventDefault();
          const html = e.clipboardData.getData("text/html");
          if (html)
            document.execCommand("insertHTML", false, cleanRichText(html));
          else
            document.execCommand(
              "insertText",
              false,
              e.clipboardData.getData("text/plain"),
            );
          if (ref.current) onChange(cleanRichText(ref.current.innerHTML));
        }}
      />
    </div>
  );
}
